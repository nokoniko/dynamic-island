//! Shared build steps for the builder binaries: the public `builder` (`cargo run`,
//! builds the app) and the maintainer-only `release` tool, which lives in
//! `src/bin/release.rs` and is kept out of git.

use ed25519_dalek::{Signer, SigningKey};
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

/// The hex Ed25519 signature written to a release's `.sig` file.
pub fn sign_hex(key: &SigningKey, data: &[u8]) -> String {
	hex(&key.sign(data).to_bytes())
}

/// The app version from VERSION, validated as dotted numbers (e.g. 1.2.0).
fn read_version() -> Res<String> {
	let raw = fs::read_to_string(VERSION_FILE)
		.map_err(|_| format!("{VERSION_FILE} not found — create it containing e.g. 1.0.0"))?;
	parse_version(&raw)
}

fn parse_version(raw: &str) -> Res<String> {
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
	parse_github_remote(&String::from_utf8(out.stdout).ok()?)
}

fn parse_github_remote(url: &str) -> Option<String> {
	let url = url.trim();
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

#[cfg(test)]
mod tests {
	use super::*;
	use std::path::PathBuf;
	use std::sync::atomic::{AtomicUsize, Ordering};

	// Throwaway key that only signs the test fixture — never a release key.
	const FIXTURE_SEED: [u8; 32] = [7; 32];

	fn fixture(name: &str) -> PathBuf {
		Path::new(env!("CARGO_MANIFEST_DIR"))
			.join("../Tests/DynamicIslandTests/Fixtures/rust-signed")
			.join(name)
	}

	#[test]
	fn signature_fixture_comes_from_the_builders_signing() {
		let key = SigningKey::from_bytes(&FIXTURE_SEED);
		let zip = fs::read(fixture("update.zip")).unwrap();
		let signature = fs::read_to_string(fixture("update.zip.sig")).unwrap();
		let public = fs::read_to_string(fixture("public_key.txt")).unwrap();
		assert_eq!(signature.trim(), sign_hex(&key, &zip));
		assert_eq!(public.trim(), hex(key.verifying_key().as_bytes()));
	}

	#[test]
	fn reads_a_dotted_version() {
		for (raw, expected) in [("1.0.0\n", "1.0.0"), ("  2.10.3  ", "2.10.3"), ("7", "7"), ("10.0", "10.0")] {
			assert_eq!(parse_version(raw).unwrap(), expected, "{raw:?}");
		}
	}

	#[test]
	fn rejects_versions_that_are_not_dotted_numbers() {
		for raw in ["", "\n", "1..0", ".1", "1.", "v1.0.0", "1.0.0-beta", "1.0 .0", "1,0"] {
			assert!(parse_version(raw).is_err(), "{raw:?} should be rejected");
		}
	}

	#[test]
	fn parses_github_remotes() {
		let cases = [
			("https://github.com/nokoniko/dynamic-island.git\n", Some("nokoniko/dynamic-island")),
			("https://github.com/nokoniko/dynamic-island", Some("nokoniko/dynamic-island")),
			("https://github.com/nokoniko/dynamic-island/", Some("nokoniko/dynamic-island")),
			("https://github.com/nokoniko/dynamic-island.git/", Some("nokoniko/dynamic-island")),
			("git@github.com:nokoniko/dynamic-island.git", Some("nokoniko/dynamic-island")),
			("ssh://git@github.com/nokoniko/dynamic-island.git", Some("nokoniko/dynamic-island")),
			("https://gitlab.com/nokoniko/dynamic-island.git", None),
			("https://github.com/nokoniko", None),
			("https://github.com/nokoniko/dynamic-island/tree/main", None),
			("", None),
		];
		for (url, expected) in cases {
			assert_eq!(parse_github_remote(url).as_deref(), expected, "{url:?}");
		}
	}

	fn plist_value(plist: &str, key: &str) -> Option<String> {
		static NEXT: AtomicUsize = AtomicUsize::new(0);
		let n = NEXT.fetch_add(1, Ordering::Relaxed);
		let path = std::env::temp_dir().join(format!("di-plist-{}-{n}.plist", std::process::id()));
		fs::write(&path, plist).unwrap();
		let lint = Command::new("plutil").args(["-lint", "-s"]).arg(&path).status().unwrap();
		assert!(lint.success(), "generated Info.plist is not a valid plist");
		let out = Command::new("plutil").args(["-extract", key, "raw", "-o", "-"]).arg(&path).output().unwrap();
		fs::remove_file(&path).ok();
		out.status.success().then(|| String::from_utf8(out.stdout).unwrap().trim().to_string())
	}

	#[test]
	fn info_plist_carries_the_version_and_update_keys() {
		let key = "ab".repeat(32);
		let plist = info_plist("1.4.2", Some("owner/repo"), Some(&key));
		assert_eq!(plist_value(&plist, "CFBundleShortVersionString").as_deref(), Some("1.4.2"));
		assert_eq!(plist_value(&plist, "CFBundleVersion").as_deref(), Some("1.4.2"));
		assert_eq!(plist_value(&plist, "DIUpdateRepo").as_deref(), Some("owner/repo"));
		assert_eq!(plist_value(&plist, "DIUpdatePublicKey").as_deref(), Some(key.as_str()));
		assert_eq!(plist_value(&plist, "CFBundleIdentifier").as_deref(), Some("com.niko.dynamicisland"));
		assert_eq!(plist_value(&plist, "LSUIElement").as_deref(), Some("true"));
	}

	#[test]
	fn info_plist_leaves_the_updater_off_unless_both_keys_are_known() {
		let key = "ab".repeat(32);
		for (repo, public_key) in [(Some("owner/repo"), None), (None, Some(key.as_str())), (None, None)] {
			let plist = info_plist("1.0.0", repo, public_key);
			assert_eq!(plist_value(&plist, "DIUpdateRepo"), None);
			assert_eq!(plist_value(&plist, "DIUpdatePublicKey"), None);
			assert_eq!(plist_value(&plist, "CFBundleShortVersionString").as_deref(), Some("1.0.0"));
		}
	}

	#[test]
	#[ignore = "rewrites the fixture; run after replacing update.zip"]
	fn regenerate_signature_fixture() {
		let key = SigningKey::from_bytes(&FIXTURE_SEED);
		let zip = fs::read(fixture("update.zip")).unwrap();
		fs::write(fixture("update.zip.sig"), format!("{}\n", sign_hex(&key, &zip))).unwrap();
		fs::write(fixture("public_key.txt"), format!("{}\n", hex(key.verifying_key().as_bytes()))).unwrap();
	}
}
