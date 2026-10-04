//! Shared build steps for the builder binaries: the public `builder` (`cargo run`,
//! builds the app) and the maintainer-only `release` tool, which lives in
//! `src/bin/release.rs` and is kept out of git.

use std::error::Error;
use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::process::{Command, Stdio};

pub type Res<T = ()> = Result<T, Box<dyn Error>>;

pub const APP: &str = "DynamicIsland.app";
pub const INSTALLED: &str = "/Applications/DynamicIsland.app";
const BIN: &str = ".build/release/DynamicIsland";
/// Single source of truth for the app version (e.g. `1.2.0`).
const VERSION_FILE: &str = "VERSION";
/// Committed public half of the update-signing key; baked into Info.plist so the
/// app only installs updates signed with the matching private key.
pub const PUBLIC_KEY_FILE: &str = "Assets/update_public_key.txt";

/// Work from the project root no matter where `cargo run` was started.
pub fn enter_project_root() -> Res {
	let root = Path::new(env!("CARGO_MANIFEST_DIR"))
		.parent()
		.ok_or("builder must live inside the project")?;
	std::env::set_current_dir(root)?;
	Ok(())
}

fn info_plist(version: &str, repo: Option<&str>, public_key: Option<&str>) -> String {
	// The updater is only switched on when both its keys are present.
	let update_keys = match (repo, public_key) {
		(Some(repo), Some(key)) => format!(
			"\t<key>DIUpdateRepo</key>\n\t<string>{repo}</string>\n\t<key>DIUpdatePublicKey</key>\n\t<string>{key}</string>\n"
		),
		_ => String::new(),
	};
	format!(
		r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>DynamicIsland</string>
	<key>CFBundleDisplayName</key>
	<string>Dynamic Island</string>
	<key>CFBundleIdentifier</key>
	<string>com.niko.dynamicisland</string>
	<key>CFBundleVersion</key>
	<string>{version}</string>
	<key>CFBundleShortVersionString</key>
	<string>{version}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleExecutable</key>
	<string>DynamicIsland</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Dynamic Island reads the currently playing track from Music and Spotify.</string>
	<key>NSHumanReadableCopyright</key>
	<string>Dynamic Island for Mac</string>
{update_keys}</dict>
</plist>
"#
	)
}

pub fn run(cmd: &str, args: &[&str]) -> Res {
	let status = Command::new(cmd).args(args).status()?;
	if !status.success() {
		return Err(format!("{} failed ({})", cmd, status).into());
	}
	Ok(())
}

fn run_quiet(cmd: &str, args: &[&str]) {
	let _ = Command::new(cmd)
		.args(args)
		.stdout(Stdio::null())
		.stderr(Stdio::null())
		.status();
}

/// Like `run`, but keeps quiet unless the command fails (then shows its stderr).
fn run_checked(cmd: &str, args: &[&str]) -> Res {
	let out = Command::new(cmd).args(args).output()?;
	if !out.status.success() {
		return Err(format!("{cmd} failed: {}", String::from_utf8_lossy(&out.stderr).trim()).into());
	}
	Ok(())
}

pub fn hex(bytes: &[u8]) -> String {
	bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// The app version from VERSION, validated as dotted numbers (e.g. 1.2.0).
fn read_version() -> Res<String> {
	let raw = fs::read_to_string(VERSION_FILE)
		.map_err(|_| format!("{VERSION_FILE} not found — create it containing e.g. 1.0.0"))?;
	let version = raw.trim().to_string();
	let valid = !version.is_empty()
		&& version.split('.').all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_digit()));
	if !valid {
		return Err(format!("{VERSION_FILE} must look like 1.2.0 (got {version:?})").into());
	}
	Ok(version)
}

/// "owner/repo" from the git `origin` remote, so a fork updates from its own releases.
pub fn github_repo() -> Option<String> {
	let out = Command::new("git").args(["remote", "get-url", "origin"]).output().ok()?;
	let url = String::from_utf8(out.stdout).ok()?.trim().to_string();
	let rest = url
		.strip_prefix("https://github.com/")
		.or_else(|| url.strip_prefix("git@github.com:"))
		.or_else(|| url.strip_prefix("ssh://git@github.com/"))?;
	let slug = rest.trim_end_matches('/').trim_end_matches(".git");
	(slug.split('/').count() == 2).then(|| slug.to_string())
}

/// The committed public key (64 hex chars), if one has been generated.
pub fn public_key() -> Option<String> {
	let key = fs::read_to_string(PUBLIC_KEY_FILE).ok()?.trim().to_lowercase();
	(key.len() == 64 && key.chars().all(|c| c.is_ascii_hexdigit())).then_some(key)
}

/// Code-signing identity: ad-hoc ("-") unless DI_SIGN_IDENTITY names a certificate.
/// A stable (even self-signed) identity lets macOS keep the Automation permissions
/// across updates; ad-hoc builds look like a brand-new app every time.
pub fn sign_identity() -> String {
	std::env::var("DI_SIGN_IDENTITY")
		.ok()
		.filter(|s| !s.is_empty())
		.unwrap_or_else(|| "-".into())
}

/// Whether to embed the custom app icon. The `DI_ICON` env var wins so the choice
/// can be made permanent without being prompted — set it in `.cargo/config.toml`'s
/// `[env]` section (DI_ICON = "1" to always add it, "0" to always skip). When unset
/// (or anything else), it asks interactively.
fn want_icon() -> bool {
	match std::env::var("DI_ICON").unwrap_or_default().to_lowercase().as_str() {
		"1" | "true" | "yes" | "always" => true,
		"0" | "false" | "no" | "never" => false,
		_ => ask("Use the custom app icon?"),
	}
}

fn build_icon(resources_dir: &str) -> Res {
	let svg = "Assets/AppIcon.svg";
	if !Path::new(svg).exists() {
		eprintln!("⚠︎ {svg} not found; skipping app icon");
		return Ok(());
	}

	println!("▶︎ Building app icon…");
	let work = ".build/iconwork";
	let iconset = ".build/AppIcon.iconset";
	let _ = fs::remove_dir_all(work);
	let _ = fs::remove_dir_all(iconset);
	fs::create_dir_all(work)?;
	fs::create_dir_all(iconset)?;

	run_quiet("qlmanage", &["-t", "-s", "1024", "-o", work, svg]);
	let master = format!("{work}/AppIcon.svg.png");
	if !Path::new(&master).exists() {
		eprintln!("⚠︎ could not rasterize {svg}; skipping app icon");
		return Ok(());
	}

	let sizes: [(u32, &str); 10] = [
		(16, "icon_16x16.png"),    (32, "icon_16x16@2x.png"),
		(32, "icon_32x32.png"),    (64, "icon_32x32@2x.png"),
		(128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
		(256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
		(512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
	];
	for (px, name) in sizes {
		let px = px.to_string();
		run_quiet("sips", &["-z", &px, &px, &master, "--out", &format!("{iconset}/{name}")]);
	}

	// Pack into .icns — but never fail the whole build over the icon.
	let icns = format!("{resources_dir}/AppIcon.icns");
	run_quiet("iconutil", &["-c", "icns", iconset, "-o", &icns]);
	if !Path::new(&icns).exists() {
		eprintln!("⚠︎ could not build AppIcon.icns; the app will use the default icon");
	}
	Ok(())
}

pub fn ask(prompt: &str) -> bool {
	print!("{} [y/N] ", prompt);
	io::stdout().flush().ok();

	let mut answer = String::new();
	io::stdin().read_line(&mut answer).ok();

	matches!(answer.trim(), "y" | "Y")
}

/// Build and assemble DynamicIsland.app. Releases always ship the icon; local
/// builds ask (or follow DI_ICON). Returns the version that was built.
pub fn build_app(release: bool) -> Res<String> {
	let version = read_version()?;
	let repo = github_repo();
	let key = public_key();
	let identity = sign_identity();

	println!("▶︎ Building release binary (v{version})…");
	run("swift", &["build", "-c", "release"])?;

	println!("▶︎ Building MediaRemote helper dylib…");
	run(
		"clang",
		&[
			"-dynamiclib",
			"-framework",
			"CoreFoundation",
			"-O2",
			"-o",
			".build/mrhelper.dylib",
			"Helpers/mrhelper.c",
		],
	)?;
	run_checked("codesign", &["--force", "--sign", &identity, ".build/mrhelper.dylib"])?;

	println!("▶︎ Assembling {APP}…");
	if Path::new(APP).exists() {
		fs::remove_dir_all(APP)?;
	}
	fs::create_dir_all(format!("{APP}/Contents/MacOS"))?;
	fs::create_dir_all(format!("{APP}/Contents/Resources"))?;
	fs::copy(BIN, format!("{APP}/Contents/MacOS/DynamicIsland"))?;
	fs::copy(
		".build/mrhelper.dylib",
		format!("{APP}/Contents/Resources/mrhelper.dylib"),
	)?;
	fs::write(
		format!("{APP}/Contents/Info.plist"),
		info_plist(&version, repo.as_deref(), key.as_deref()),
	)?;
	if repo.is_none() || key.is_none() {
		eprintln!("⚠︎ updater is off in this build (needs a GitHub `origin` remote and {PUBLIC_KEY_FILE})");
	}

	if release || want_icon() {
		build_icon(&format!("{APP}/Contents/Resources"))?;
	}

	run_checked("codesign", &["--force", "--deep", "--sign", &identity, APP])?;

	println!("✓ Built {APP} v{version}");
	Ok(version)
}
