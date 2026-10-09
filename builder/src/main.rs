use builder::{APP, INSTALLED, LEGACY_INSTALLED, Res, ask, build_app, enter_project_root, run};
use std::fs;
use std::path::Path;

/// `cargo run`: build Hevel.app, then optionally install it to
/// /Applications and open it.
fn main() -> Res {
	match std::env::args().nth(1).as_deref() {
		None => {}
		Some("release") | Some("keygen") => {
			return Err("releasing moved to its own tool: `cargo run --bin release` \
				(or `cargo run --bin release -- keygen`)"
				.into());
		}
		Some(_) => {
			return Err("`cargo run` takes no arguments — it just builds Hevel.app".into());
		}
	}
	enter_project_root()?;
	build_app(false)?;

	let mut to_open = APP;
	if ask("Do you want to move it to /Applications/?") {
		if Path::new(INSTALLED).exists() {
			fs::remove_dir_all(INSTALLED)?;
		}
		run("ditto", &[APP, INSTALLED])?;
		println!("Moved {APP} to /Applications/");
		// The same app under its name from before the rename — don't leave two around.
		if Path::new(LEGACY_INSTALLED).exists() {
			fs::remove_dir_all(LEGACY_INSTALLED)?;
			println!("Removed the old {LEGACY_INSTALLED}");
		}
		to_open = INSTALLED;
	}

	if ask("Do you want to open the app now?") {
		run("open", &[to_open])?;
		println!("Opened {to_open}");
	}
	Ok(())
}
