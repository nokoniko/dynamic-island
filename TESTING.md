# Testing

## Running the tests

```bash
./test.sh
```

Runs both suites: the Swift tests (Swift Testing) and the builder's Rust tests.

With Xcode installed you can also run them directly:

```bash
swift test
cd builder && cargo test
```

> **Command Line Tools only (no Xcode)?** Use `./test.sh`. The Command Line Tools ship
> Swift Testing outside SwiftPM's search paths, and plain `swift test` then builds the
> tests, runs **zero** of them and still reports success. `test.sh` adds the missing paths.

CI runs both suites on `macos-latest` for every push to `main` and every pull request
(`.github/workflows/tests.yml`).

## What's covered

| Area | Tests | What they pin down |
|---|---|---|
| Updater | `ReleaseFeedTests`, `UpdateSignatureTests` | Numeric version comparison; signature checks (valid, tampered zip, wrong key, empty or non-hex `.sig`, bad public keys) |
| Install | `UpdateInstallerTests` | Picks `Hevel.app` from an update, falls back to `DynamicIsland.app` (releases from before the rename) |
| Rust ↔ CryptoKit | `RustSignedFixtureTests` + `signature_fixture_comes_from_the_builders_signing` | A zip signed by the builder's `sign_hex` verifies in CryptoKit, and fails once tampered |
| Media flow | `ReconcileTests`, `PauseLingerTests` | The three reconcile rules, `sameTrack`, and which sources linger on pause |
| Parsing | `StreamLineParsingTests`, `AppleScriptParsingTests`, `BrowserScriptParsingTests` | Broken lines, missing fields, Spotify ms vs Music seconds, comma decimals, live-stream durations |
| Settings | `UpdateScheduleTests`, `SettingsSearchTests`, `PreferencesTests` | Next update check per frequency/time of day (missed and late checks, clock changes); search by title, keyword and pane name; defaults |
| Window | `NotchGeometryTests`, `FullscreenDetectionTests`, `PopoutTests`, `FrontmostTests` | Notch metrics with/without a notch, fullscreen overlay detection on fake window lists, pop-out visibility, frontmost matching |
| Builder | `cargo test` in `builder/` | `VERSION` parsing, generated `Info.plist` (validated with `plutil`), GitHub remote parsing |

The tests exercise pure functions; the code around them only fetches system data
(screens, windows, running apps, AppleScript, the python3 helper) and passes it in.

### The signed fixture

`Tests/HevelTests/Fixtures/rust-signed/` holds a small zip signed with a
throwaway test key (seed `[7; 32]` in `builder/src/lib.rs`) — never a release key. If
you replace `update.zip`, re-sign it:

```bash
cd builder && cargo test -- --ignored regenerate_signature_fixture
```

## Manual checklist

Run through this before a release. These depend on the live system and can't run in CI.

**Now playing (MediaRemote via python3)**
- [ ] Play in Spotify, Apple Music and a browser (YouTube): art appears left of the notch, equalizer right.
- [ ] `pgrep -fl mr_stream` shows exactly one helper process, also after a few track changes.
- [ ] Pause Spotify/Music: the art shrinks and dims, then disappears after ~5 s. Resume within 5 s: it springs back.
- [ ] Pause or leave a browser video: the island hides at once.
- [ ] Next track flips the cover to the right, previous to the left, with the white glint (~1.1 s).
- [ ] Playing app in front: island hidden. Switch to another app: it comes back.

**Lock screen (SkyLight)**
- [ ] Lock with Ctrl+Cmd+Q: a lock icon shows left of the notch on the lock screen.
- [ ] Unlock: the lock icon is gone and the normal island works.

**Animations and charging**
- [ ] Pop-out slides out from behind the notch (not a fade).
- [ ] Plug in power: the ring draws to the battery level in ~1.1 s (red < 20 %, orange < 80 %, green ≥ 80 %) and the flourish disappears after ~3 s.

**Click-through and fullscreen**
- [ ] While music plays, menu-bar icons next to the notch are still clickable.
- [ ] Clicking the island brings the playing app to the front.
- [ ] Nothing playing: clicks anywhere near the notch pass straight through.
- [ ] Fullscreen app on the notched screen: island hidden; leave fullscreen: it returns.

**Updating with permissions kept**
- [ ] An install from before the rename (`/Applications/DynamicIsland.app`, ≤ 2.1.1) updates to the new release and comes back as `Hevel.app`, settings intact.
- [ ] Install the previous release in Applications, grant Automation for Spotify/Music.
- [ ] Publish a newer release, then **Check for Updates…** → **Update**: the app relaunches on the new version.
- [ ] Spotify/Music access is **not** asked for again (requires a stable `DI_SIGN_IDENTITY`).
- [ ] With **Install updates automatically** on: a background check installs a newer release without a prompt, but only once nothing is playing and settings is closed; the island comes back on the new version.
- [ ] **Skip This Version** stops the background prompt for that version; **Later** asks again next check.
- [ ] Running from Downloads (translocated) shows the "Move Hevel to your Applications folder" message.

**Settings**
- [ ] Menu bar icon → **Settings…** opens the window centered on the screen you're on and in front of other apps (even with another app active); opening it again reuses the window without moving it.
- [ ] While it's open the app is in the Dock and ⌘Tab; ⌘W closes it and the Dock icon goes away.
- [ ] ⌘Q in settings asks "Quit Hevel?"; **Cancel** keeps everything running, **Quit** quits. Quit from the menu bar icon quits without asking.
- [ ] **Launch at login** survives a log out/in (or asks to be allowed in Login Items).
- [ ] Each toggle takes effect without a restart: hiding while the player is in front, the cover flip, the charging animation, the lock icon.
- [ ] **Show in fullscreen apps** (off by default): off hides the island in fullscreen; on keeps it showing there.
- [ ] With automatic updates off, no update prompt appears on launch; **Check Now** still works (spinner while checking).
- [ ] General shows the version; after a check, "Last checked" and "Next" match the chosen frequency and time of day. **Time of day** is greyed out for **Every hour**.
- [ ] Search: "lock" leaves only Island with the lock row, "update" only General, nonsense shows "No Results"; clearing it brings everything back.

**Memory**
- [ ] `footprint -t $(pgrep -f Hevel.app/Contents/MacOS) | grep phys_footprint` is about 27–30 MB idle.
- [ ] The python3 helper stays around 5 MB (`ps -o rss= -p $(pgrep -f mr_stream)`).
- [ ] After 30+ minutes of playback and track changes the numbers haven't crept up.
