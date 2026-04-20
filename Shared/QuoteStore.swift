import Foundation
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

enum QuoteStore {
    struct Diagnostics {
        let fileExists: Bool
        let quoteCount: Int
        let lastSync: Date?
        let refreshIntervalSeconds: Int
        let errorDescription: String?
    }

    private struct SharedPayload: Codable {
        var quotes: [Quote]
        var lastSync: Date?
        var refreshIntervalSeconds: Int
    }

    private struct PayloadReadResult {
        let data: Data?
        let errorDescription: String?
    }

    private static let logger = Logger(subsystem: "com.jonathanlamela.NotionQuotes", category: "QuoteStore")

    private static var sharedDefaults: UserDefaults? {
        UserDefaults.standard
    }

    private static func readPayloadData() -> PayloadReadResult {
        if let data = sharedDefaults?.data(forKey: SharedConstants.sharedPayloadDefaultsKey) {
            return PayloadReadResult(data: data, errorDescription: nil)
        }

        return PayloadReadResult(data: nil, errorDescription: "Cache locale non inizializzata")
    }

    private static func loadPayload() -> SharedPayload {
        let diagnostics = loadDiagnostics()
        if let errorDescription = diagnostics.errorDescription {
            if diagnostics.quoteCount > 0 {
                logger.debug("Shared payload loaded with fallback: \(errorDescription, privacy: .public)")
            } else {
                logger.error("Shared payload unavailable: \(errorDescription, privacy: .public)")
            }
        } else {
            logger.debug("Loaded local payload with \(diagnostics.quoteCount) quotes")
        }

        let readResult = readPayloadData()
        if let readError = readResult.errorDescription, readResult.data == nil {
            logger.error("Shared payload read details: \(readError, privacy: .public)")
        }

        guard let data = readResult.data else {
            return SharedPayload(
                quotes: [],
                lastSync: nil,
                refreshIntervalSeconds: SharedConstants.defaultRefreshIntervalSeconds
            )
        }

        do {
            return try JSONDecoder().decode(SharedPayload.self, from: data)
        } catch {
            return SharedPayload(
                quotes: [],
                lastSync: nil,
                refreshIntervalSeconds: SharedConstants.defaultRefreshIntervalSeconds
            )
        }
    }

    static func loadDiagnostics() -> Diagnostics {
        let readResult = readPayloadData()

        guard let data = readResult.data else {
            return Diagnostics(
                fileExists: false,
                quoteCount: 0,
                lastSync: nil,
                refreshIntervalSeconds: SharedConstants.defaultRefreshIntervalSeconds,
                errorDescription: readResult.errorDescription ?? "payload locale non presente"
            )
        }

        do {
            let payload = try JSONDecoder().decode(SharedPayload.self, from: data)
            return Diagnostics(
                fileExists: true,
                quoteCount: payload.quotes.count,
                lastSync: payload.lastSync,
                refreshIntervalSeconds: payload.refreshIntervalSeconds,
                errorDescription: readResult.errorDescription == "fallback plist preferenze App Group" ? nil : readResult.errorDescription
            )
        } catch {
            return Diagnostics(
                fileExists: true,
                quoteCount: 0,
                lastSync: nil,
                refreshIntervalSeconds: SharedConstants.defaultRefreshIntervalSeconds,
                errorDescription: error.localizedDescription
            )
        }
    }

    private static func savePayload(_ payload: SharedPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            sharedDefaults?.set(data, forKey: SharedConstants.sharedPayloadDefaultsKey)
        } catch {
            logger.error("Unable to save shared payload: \(error.localizedDescription, privacy: .public)")
            return
        }

        reloadTimelines()
    }

    static func loadQuotes() -> [Quote] {
        loadPayload().quotes
    }

    static func saveQuotes(_ quotes: [Quote], syncedAt: Date = Date()) {
        var payload = loadPayload()
        payload.quotes = quotes
        payload.lastSync = syncedAt
        savePayload(payload)
    }

    static func loadLastSync() -> Date? {
        loadPayload().lastSync
    }

    static func loadRefreshInterval() -> Int {
        max(loadPayload().refreshIntervalSeconds, SharedConstants.minimumRefreshIntervalSeconds)
    }

    static func saveRefreshInterval(_ seconds: Int) {
        var payload = loadPayload()
        payload.refreshIntervalSeconds = max(seconds, SharedConstants.minimumRefreshIntervalSeconds)
        savePayload(payload)
    }

    static func refreshWidgetTimelines() {
        reloadTimelines()
    }

    private static func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
