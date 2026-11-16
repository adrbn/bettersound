<p align="center"><img src="docs/icon.png" width="128" alt=""></p>

# BetterSound

Volume for each app on macOS. It takes the place of Apple's Sound menu, in the menu bar and in Control Center, and looks the same. Free, open source, no audio driver.

- A slider for each app that is playing. Click the app icon to mute it.
- Send one app to another output: a call on the AirPods, music on the speakers. If that device disconnects, the app goes back to the system output, and returns when the device comes back.
- The menu bar icon follows the output, like Apple's (AirPods, speakers, display).
- Clicking Sound in Control Center opens BetterSound instead. The volume slider there still works.
- Apps left at 100% on the system output are not touched at all.

## Requirements

- macOS 26
- **Screen & System Audio Recording**, to change each app's volume. Nothing is recorded or saved.
- **Accessibility**, to open from Control Center's Sound control.

BetterSound hides Apple's Sound item from the menu bar while it runs and puts it back when you quit.

## How it works

Core Audio process taps (`CATapDescription`, `.mutedWhenTapped`) silence an app at the source; a private aggregate device plays its audio back, scaled, on the chosen output. This adds a few milliseconds of latency, only for apps you changed.

## Build

```bash
brew install xcodegen
make build                    # ad-hoc signed
make install TEAM=XXXXXXXXXX  # Developer ID signed, copied to /Applications
```

macOS keeps the audio permission across rebuilds only for a signed build.

## License

MIT
