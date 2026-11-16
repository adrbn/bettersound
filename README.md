# BetterSound

Volume for each app on macOS, in Control Center and the menu bar. Free, open source, no driver.

- A slider per app that is playing; click the app icon to mute it.
- Send one app to another output (call on AirPods, music on the speakers). If that device disconnects, the app falls back to the system output and returns when the device comes back.
- Apps left at 100% on the system output are not touched at all.

Needs macOS 26 and the "Screen & System Audio Recording" permission. Nothing is recorded or saved.

## How it works

Core Audio process taps (`CATapDescription`, `.mutedWhenTapped`) silence an app at the source; a private aggregate device plays its audio back, scaled, on the chosen output. Adds a few milliseconds of latency, only for apps you changed.

## Build

```bash
brew install xcodegen
make build                   # ad-hoc signed
make install TEAM=XXXXXXXXXX # Developer ID signed, copied to /Applications
```

Then Control Center → Edit Controls → add **BetterSound**. You can remove Apple's Sound control from there too.
