import AppIntents
import Foundation

extension Notification.Name {
    static let showBetterSound = Notification.Name("dev.adrbn.bettersound.show")
}

/// Run by the Control Center control. Compiled into both targets; `openAppWhenRun`
/// makes the system perform it inside the app, which then shows the mixer.
struct ShowMixerIntent: AppIntent {
    static let title: LocalizedStringResource = "Show BetterSound"
    static let description = IntentDescription("Opens the per-app volume mixer.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .showBetterSound, object: nil)
        return .result()
    }
}
