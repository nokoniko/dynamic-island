use builder::{APP, INSTALLED, Res, ask, build_app, enter_project_root, run};
use std::fs;
use std::path::Path;

/// `cargo run`: build DynamicIsland.app, then optionally install it to
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
			return Err("`cargo run` takes no arguments — it just builds DynamicIsland.app".into());
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
		to_open = INSTALLED;
	}

	if ask("Do you want to open the app now?") {
		run("open", &[to_open])?;
		println!("Opened {to_open}");
	}
	Ok(())
}
