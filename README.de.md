<p align="center"><picture>
  <source media="(prefers-color-scheme: light)" srcset="docs/assets/hero-light.svg">
  <img src="docs/assets/hero.svg" width="520" alt="BetterSound in der macOS-Menüleiste: Systemlautstärke, ein Lautstärkeregler pro App, die Ausgänge mit dem AirPods-Akku und die Ton-Einstellungen.">
</picture></p>

<p align="center"><img src="docs/icon.png" width="96" alt="BetterSound"></p>

<h1 align="center">BetterSound</h1>

<p align="center"><b>Ein Lautstärkeregler für jede App, direkt im Ton-Menü von Apple.</b><br>
BetterSound ersetzt das Ton-Symbol in der Menüleiste und im Kontrollzentrum, sieht genauso aus und ergänzt Lautstärke, Stummschaltung und Ausgang pro App.</p>

<p align="center">
  <a href="https://github.com/adrbn/bettersound/releases/latest/download/BetterSound.dmg"><img src="docs/assets/btn-download.svg" height="48" alt="Für macOS 26 laden"></a>
  <a href="#funktionen"><img src="docs/assets/btn-features.svg" height="48" alt="Funktionen"></a>
  <a href="#so-funktioniert-es"><img src="docs/assets/btn-how.svg" height="48" alt="So funktioniert es"></a>
  <a href="https://ko-fi.com/adrbn"><img src="docs/assets/btn-kofi.svg" height="48" alt="Ko-fi"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%2B-FAC233?style=flat-square&labelColor=121212" alt="macOS 26+">
  <img src="https://img.shields.io/github/v/release/adrbn/bettersound?style=flat-square&labelColor=121212&color=FAC233" alt="release">
  <img src="https://img.shields.io/badge/license-MIT-FAC233?style=flat-square&labelColor=121212" alt="MIT">
  <img src="https://img.shields.io/badge/notarized-Apple-FAC233?style=flat-square&labelColor=121212" alt="notarized">
  <img src="https://img.shields.io/badge/audio%20driver-none-FAC233?style=flat-square&labelColor=121212" alt="no audio driver">
</p>

<p align="center">Kostenlos und Open Source · eine kostenlose Alternative zu Native Sound Mixer · 23 Sprachen</p>

<p align="center"><sub><a href="README.md">English</a> · <a href="README.fr.md">Français</a> · <b>Deutsch</b> · <a href="README.es.md">Español</a> · <a href="README.it.md">Italiano</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">简体中文</a></sub></p>

---

macOS hat eine einzige Lautstärke für alles. BetterSound gibt jeder App ihren eigenen Regler, ihre Stummschaltung und ihren Ausgang, in dem Menü, das Sie schon benutzen: Es sitzt an der Stelle von Apples Ton-Symbol, öffnet sich beim Klick auf Ton im Kontrollzentrum und übernimmt Apples Layout bis zu den Gerätezeilen. Kein Audiotreiber, keine Kernel-Erweiterung, nichts einzurichten.

## Was es macht

<table>
  <tr>
    <td width="33%"><img src="docs/assets/card-apps.svg" width="100%" alt="Ein Regler pro App"><br><b>Ein Regler pro App</b><br>Jede App, die Ton abspielt, bekommt eine Zeile.</td>
    <td width="33%"><img src="docs/assets/card-mute.svg" width="100%" alt="Klick zum Stummschalten"><br><b>Klick zum Stummschalten</b><br>Klicken Sie auf das Symbol einer App.</td>
    <td width="33%"><img src="docs/assets/card-route.svg" width="100%" alt="Eigener Ausgang"><br><b>Eigener Ausgang</b><br>Ein Anruf auf den AirPods, ein Film auf den Lautsprechern.</td>
  </tr>
  <tr>
    <td><img src="docs/assets/card-battery.svg" width="100%" alt="AirPods-Akku"><br><b>AirPods-Akku</b><br>Neben dem Gerät, wie bei Apple.</td>
    <td><img src="docs/assets/card-icon.svg" width="100%" alt="Symbol folgt dem Ausgang"><br><b>Symbol folgt dem Ausgang</b><br>Dieselben Symbole wie Apples Ton-Menü.</td>
    <td><img src="docs/assets/card-light.svg" width="100%" alt="Klein und nativ"><br><b>Klein und nativ</b><br>Core-Audio-Taps, SwiftUI, nichts systemweit installiert.</td>
  </tr>
</table>

## Funktionen

**Pro App**
- Ein Lautstärkeregler für jede App, die Ton abspielt. Hilfsprozesse und Kommandozeilen-Player zählen zur App, die sie gestartet hat.
- Klicken Sie auf das App-Symbol zum Stummschalten, ziehen Sie den Regler zum Aufheben.
- Senden Sie eine App über die Taste am Zeilenende an einen anderen Ausgang. Trennt sich das Gerät, spielt die App auf dem Systemausgang und kehrt zurück, wenn es wieder da ist.
- Apps bei 100 % auf dem Systemausgang werden gar nicht angefasst: kein Tap, keine Latenz.
- Lautstärke, Stummschaltung und Ausgang werden pro App gespeichert.

**Apples Ton-Menü, ersetzt**
- Nimmt den Platz von Apples Ton-Symbol in der Menüleiste ein; Apples Symbol ist ausgeblendet, solange BetterSound läuft, und kommt beim Beenden zurück.
- Ein Klick auf Ton im Kontrollzentrum öffnet BetterSound. Der Lautstärkeregler und die AirPlay-Taste dort funktionieren weiter.
- Das Menüleisten-Symbol zeigt den Ausgang (AirPods, Lautsprecher, Display) oder die Lautstärke, wie bei Apple.
- Ausgangsliste mit Bluetooth-Akkustand und Link zu den Ton-Einstellungen.
- Liquid-Glass-Fenster, das hellem und dunklem Modus folgt.

**Die App**
- Startet bei der Anmeldung. Rechtsklick auf das Symbol: Beim Anmelden öffnen, Nach Updates suchen, GitHub, Ko-fi, Beenden.
- Automatische Updates (Sparkle, EdDSA-signiert).
- 23 Sprachen: English, Français, Deutsch, Español, Italiano, Português, Nederlands, Svenska, Norsk, Dansk, Suomi, Polski, Čeština, Română, Türkçe, Ελληνικά, Русский, Українська, 简体中文, 繁體中文, 日本語, 한국어, ไทย.

## Installation

1. Laden Sie [BetterSound.dmg](https://github.com/adrbn/bettersound/releases/latest/download/BetterSound.dmg). Sie ist mit einer Developer ID signiert und von Apple notarisiert.
2. Ziehen Sie BetterSound in Programme und öffnen Sie es.
3. Erlauben Sie **Bedienungshilfen**, wenn gefragt, und klicken Sie im Fenster auf **Allow** für System-Audio.

Updates kommen von selbst, oder per Rechtsklick auf das Symbol → **Check for Updates…**.

## Voraussetzungen

- macOS 26 Tahoe oder neuer.
- **Bildschirm- und System-Audioaufnahme**, um die Lautstärke jeder App zu ändern. Nichts wird aufgenommen oder gespeichert.
- **Bedienungshilfen**, um sich vom Ton-Regler im Kontrollzentrum zu öffnen.

## So funktioniert es

Core-Audio-Prozess-Taps (`CATapDescription` mit `.mutedWhenTapped`) schalten eine App an der Quelle stumm; ein privates Aggregatgerät spielt ihren Ton skaliert auf dem gewählten Ausgang ab. Das kostet einige Millisekunden Latenz, nur für Apps, die Sie geändert haben. Für das Kontrollzentrum liest BetterSound dessen Layout über die Bedienungshilfen und macht aus einem Klick auf die Ton-Kachel das BetterSound-Fenster.

Bekannte Grenze: Wechseln Sie den Ausgang außerhalb von BetterSound (AirPlay-Taste von Apple, andere App), während eine App ihre eigene Lautstärke hat, kann macOS zurückspringen. Aus BetterSound heraus funktioniert es.

## Aus dem Quellcode bauen

```bash
brew install xcodegen
make build                     # ad-hoc
make install TEAM=XXXXXXXXXX   # Developer ID → /Applications
make release TAG=v0.1.1        # notarized DMG + Sparkle appcast
```

macOS behält die Audio-Erlaubnis über Neubauten nur bei signierten Builds. Die README-Grafiken entstehen aus echten Aufnahmen: `python3 docs/assets/make_svgs.py`.

## Datenschutz

BetterSound liest Audio nur, um die Lautstärke zu ändern und es wiederzugeben. Nichts wird aufgenommen, gespeichert oder gesendet. Die einzige Netzwerkanfrage ist die Update-Prüfung gegen die Releases dieses Repositorys.

## Unterstützen

BetterSound ist kostenlos. Wenn es Ihnen hilft, können Sie mir einen Kaffee spendieren.

<p><a href="https://ko-fi.com/adrbn"><img src="docs/assets/btn-kofi.svg" height="48" alt="Ko-fi"></a></p>

## Lizenz

MIT: benutzen, ändern, weitergeben, Hinweis behalten. Siehe [LICENSE](LICENSE).

## Danksagung

[Sparkle](https://sparkle-project.org) für Updates. Inspiriert von Native Sound Mixer und Apples Ton-Menü.

<sub>BetterSound ist weder mit Apple noch mit Native Sound Mixer verbunden. macOS, AirPods und Kontrollzentrum sind Marken von Apple Inc.</sub>
