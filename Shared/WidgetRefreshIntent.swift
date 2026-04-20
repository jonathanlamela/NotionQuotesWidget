import AppIntents
import WidgetKit

struct ForceRefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Forza refresh widget"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
