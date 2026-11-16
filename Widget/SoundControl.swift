import AppIntents
import SwiftUI
import WidgetKit

@main
struct BetterSoundWidgets: WidgetBundle {
    var body: some Widget { SoundControl() }
}

struct SoundControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.adrbn.bettersound.sound") {
            ControlWidgetButton(action: ShowMixerIntent()) {
                Label("BetterSound", systemImage: "speaker.wave.2.fill")
            }
        }
        .displayName("BetterSound")
        .description("Volume for each app.")
    }
}
