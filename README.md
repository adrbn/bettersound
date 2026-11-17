<p align="center"><picture>
  <source media="(prefers-color-scheme: light)" srcset="docs/assets/hero-light.svg">
  <img src="docs/assets/hero.svg" width="520" alt="BetterSound open from the macOS menu bar: the system volume, a volume slider for each app that is playing (the sliders move between three real states), the outputs with the AirPods battery at 68 %, and Sound Settings.">
</picture></p>

<p align="center"><img src="docs/icon.png" width="96" alt="BetterSound icon"></p>

<h1 align="center">BetterSound</h1>

<p align="center"><b>A volume slider for every app, right inside Apple's Sound menu.</b><br>
BetterSound replaces the Sound item in the macOS menu bar and in Control Center, looks the same, and adds per-app volume, mute and output.</p>

<p align="center">
  <a href="https://github.com/adrbn/bettersound/releases/latest/download/BetterSound.dmg"><img src="docs/assets/btn-download.svg" height="48" alt="Download for macOS 26"></a>
  <a href="#features"><img src="docs/assets/btn-features.svg" height="48" alt="Features"></a>
  <a href="#how-it-works"><img src="docs/assets/btn-how.svg" height="48" alt="How it works"></a>
  <a href="https://ko-fi.com/adrbn"><img src="docs/assets/btn-kofi.svg" height="48" alt="Buy me a coffee on Ko-fi"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%2B-FAC233?style=flat-square&labelColor=121212" alt="macOS 26+">
  <img src="https://img.shields.io/github/v/release/adrbn/bettersound?style=flat-square&labelColor=121212&color=FAC233" alt="Latest release">
  <img src="https://img.shields.io/badge/license-MIT-FAC233?style=flat-square&labelColor=121212" alt="MIT license">
  <img src="https://img.shields.io/badge/notarized-Apple-FAC233?style=flat-square&labelColor=121212" alt="Notarized by Apple">
  <img src="https://img.shields.io/badge/audio%20driver-none-FAC233?style=flat-square&labelColor=121212" alt="No audio driver">
</p>

<p align="center">Free and open source · a free alternative to Native Sound Mixer · 23 languages</p>

<p align="center"><sub><b>English</b> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.es.md">Español</a> · <a href="README.it.md">Italiano</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">简体中文</a></sub></p>

---

macOS has one volume for everything. BetterSound gives each app its own slider, mute and output, in the menu you already use: it sits in Apple's Sound slot in the menu bar, opens when you click Sound in Control Center, and copies Apple's layout down to the device rows. No audio driver, no kernel extension, nothing to configure.

## What it does

<table>
  <tr>
    <td width="33%"><img src="docs/assets/card-apps.svg" width="100%" alt="Three app volume sliders moving"><br><b>A slider per app</b><br>Every app that is playing gets its own row.</td>
    <td width="33%"><img src="docs/assets/card-mute.svg" width="100%" alt="An app row going muted and back"><br><b>Click to mute</b><br>Click an app's icon to silence it.</td>
    <td width="33%"><img src="docs/assets/card-route.svg" width="100%" alt="VLC routed to the MacBook speakers"><br><b>Its own output</b><br>A call on the AirPods, a film on the speakers.</td>
  </tr>
  <tr>
    <td><img src="docs/assets/card-battery.svg" width="100%" alt="Output list with the AirPods battery level"><br><b>AirPods battery</b><br>Shown next to the device, like Apple's.</td>
    <td><img src="docs/assets/card-icon.svg" width="100%" alt="The menu bar icon changing between AirPods, MacBook and display"><br><b>Icon follows the output</b><br>Same symbols as Apple's Sound item.</td>
    <td><img src="docs/assets/card-light.svg" width="100%" alt="1 082 lines of Swift, 0 drivers or kernel extensions"><br><b>Small and native</b><br>Core Audio taps, SwiftUI, nothing installed system-wide.</td>
  </tr>
</table>

## Features

**Per app**
- A volume slider for each app that is playing sound. Helpers and command-line players are counted under the app that launched them.
- Click the app's icon to mute it, drag the slider to unmute.
- Send an app to another output from the button at the end of its row. If that device disconnects, the app plays on the system output and goes back when the device returns.
- Apps left at 100 % on the system output are not touched at all: no tap, no latency.
- Volumes, mutes and outputs are remembered per app.

**Apple's Sound menu, replaced**
- Takes the place of Apple's Sound item in the menu bar; Apple's item is hidden while BetterSound runs and comes back when you quit.
- Clicking Sound in Control Center opens BetterSound in its place. The volume slider and the AirPlay button there keep working.
- The menu bar icon shows the current output (AirPods, speakers, display) or the volume level, like Apple's.
- Output list with Bluetooth battery levels, and a link to Sound Settings.
- Liquid Glass panel that follows light and dark mode.

**App**
- Opens at login. Right-click the icon for Open at Login, Check for Updates, GitHub, Ko-fi and Quit.
- Automatic updates (Sparkle, signed with EdDSA).
- 23 languages: English, Français, Deutsch, Español, Italiano, Português, Nederlands, Svenska, Norsk, Dansk, Suomi, Polski, Čeština, Română, Türkçe, Ελληνικά, Русский, Українська, 简体中文, 繁體中文, 日本語, 한국어, ไทย.

## Install

1. Download [BetterSound.dmg](https://github.com/adrbn/bettersound/releases/latest/download/BetterSound.dmg). It is signed with a Developer ID and notarized by Apple.
2. Drag BetterSound to Applications and open it.
3. Allow **Accessibility** when asked, then click **Allow** in the panel for system audio.

Updates arrive on their own. You can also right-click the icon and choose **Check for Updates…**.

## Requirements

- macOS 26 Tahoe or later.
- **Screen & System Audio Recording**, to change each app's volume. Nothing is recorded or saved.
- **Accessibility**, to open from Control Center's Sound control.

## How it works

Core Audio process taps (`CATapDescription` with `.mutedWhenTapped`) silence an app at the source; a private aggregate device plays its audio back, scaled, on the chosen output. This adds a few milliseconds of latency, only for apps you changed. The Control Center hook reads Control Center's layout through Accessibility and turns a click on the Sound tile into BetterSound's panel.

Known limit: if you change the output outside BetterSound (from Apple's AirPlay button or another app) while an app has its own volume, macOS may switch back. Changing it from BetterSound works.

## Build from source

```bash
brew install xcodegen
make build                     # ad-hoc signed
make install TEAM=XXXXXXXXXX   # Developer ID signed, copied to /Applications
make release TAG=v0.1.1        # notarized DMG + Sparkle appcast on GitHub Releases
```

macOS keeps the audio permission across rebuilds only for a signed build. The README art is generated from real captures: `python3 docs/assets/make_svgs.py`.

## Privacy

BetterSound reads audio only to change its volume and play it back. Nothing is recorded, stored or sent. The only network request is the update check against this repository's releases.

## Support

BetterSound is free. If it saves you a menu, you can buy me a coffee.

<p>
  <a href="https://ko-fi.com/adrbn"><img src="docs/assets/btn-kofi.svg" height="48" alt="Buy me a coffee on Ko-fi"></a>
</p>

## License

MIT: use it, change it, ship it, keep the notice. See [LICENSE](LICENSE).

## Credits

[Sparkle](https://sparkle-project.org) for updates. Inspired by Native Sound Mixer and Apple's own Sound menu.

<sub>BetterSound is not affiliated with Apple or with Native Sound Mixer. macOS, AirPods and Control Center are trademarks of Apple Inc.</sub>
