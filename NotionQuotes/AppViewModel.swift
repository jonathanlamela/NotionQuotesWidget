import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var notionToken: String
    @Published var databaseID: String
    @Published var titlePropertyName: String
    @Published var sourcePropertyName: String
    @Published var refreshIntervalSeconds: Int
    @Published private(set) var quotes: [Quote]
    @Published private(set) var lastSync: Date?
    @Published private(set) var isSyncing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var diagnosticsSummary: String = ""

    private let defaults: UserDefaults
    private let notionAPI: NotionAPI

    init(defaults: UserDefaults = .standard, notionAPI: NotionAPI = NotionAPI()) {
        self.defaults = defaults
        self.notionAPI = notionAPI
        self.notionToken = defaults.string(forKey: SharedConstants.notionTokenKey) ?? ""
        self.databaseID = defaults.string(forKey: SharedConstants.notionDatabaseIDKey) ?? ""
        self.titlePropertyName = defaults.string(forKey: SharedConstants.notionTitlePropertyNameKey) ?? "Title"
        self.sourcePropertyName = defaults.string(forKey: SharedConstants.notionSourcePropertyNameKey) ?? "Source"
        self.refreshIntervalSeconds = QuoteStore.loadRefreshInterval()
        self.quotes = QuoteStore.loadQuotes()
        self.lastSync = QuoteStore.loadLastSync()
        self.diagnosticsSummary = Self.makeDiagnosticsSummary()
    }

    var canSync: Bool {
        !notionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !databaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !titlePropertyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sourcePropertyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveSettings() {
        defaults.set(notionToken.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SharedConstants.notionTokenKey)
        defaults.set(databaseID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SharedConstants.notionDatabaseIDKey)
        defaults.set(titlePropertyName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SharedConstants.notionTitlePropertyNameKey)
        defaults.set(sourcePropertyName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SharedConstants.notionSourcePropertyNameKey)
        QuoteStore.saveRefreshInterval(refreshIntervalSeconds)

        SharedFileConfig.save(.init(
            notionToken: notionToken.trimmingCharacters(in: .whitespacesAndNewlines),
            databaseID: databaseID.trimmingCharacters(in: .whitespacesAndNewlines),
            titlePropertyName: titlePropertyName.trimmingCharacters(in: .whitespacesAndNewlines),
            sourcePropertyName: sourcePropertyName.trimmingCharacters(in: .whitespacesAndNewlines),
            refreshIntervalSeconds: refreshIntervalSeconds,
            quotes: quotes,
            lastSync: lastSync
        ))

        refreshFromSharedStore()
        statusMessage = "Configurazione salvata."
        errorMessage = nil
    }

    func refreshFromSharedStore() {
        quotes = QuoteStore.loadQuotes()
        lastSync = QuoteStore.loadLastSync()
        refreshIntervalSeconds = QuoteStore.loadRefreshInterval()
        diagnosticsSummary = Self.makeDiagnosticsSummary()
    }

    func forceRefreshWidget() {
        refreshFromSharedStore()
        QuoteStore.refreshWidgetTimelines()
        statusMessage = quotes.isEmpty
            ? "Refresh forzato inviato al widget. Il widget rigenerera subito la timeline, ma nell'app non risultano frasi in cache locale."
            : "Refresh forzato inviato al widget. Timeline invalidate, cache locale app: \(quotes.count) frasi."
        errorMessage = nil
    }

    private static func makeDiagnosticsSummary() -> String {
        let diagnostics = QuoteStore.loadDiagnostics()
        let payloadState = diagnostics.fileExists ? "cache locale ok" : "cache locale assente"
        let errorState = diagnostics.errorDescription ?? "nessun errore"
        return "Cache: \(diagnostics.quoteCount) frasi, \(payloadState), errore: \(errorState)"
    }

    func syncQuotes() async {
        guard canSync else {
            errorMessage = "Inserisci token Notion, database ID, nome campo titolo e nome campo fonte prima di sincronizzare."
            statusMessage = nil
            return
        }

        saveSettings()
        isSyncing = true
        defer { isSyncing = false }

        do {
            let fetchedQuotes = try await notionAPI.fetchQuotes(
                token: notionToken.trimmingCharacters(in: .whitespacesAndNewlines),
                databaseID: databaseID.trimmingCharacters(in: .whitespacesAndNewlines),
                titlePropertyName: titlePropertyName.trimmingCharacters(in: .whitespacesAndNewlines),
                sourcePropertyName: sourcePropertyName.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            guard !fetchedQuotes.isEmpty else {
                errorMessage = "Il database Notion non ha restituito record validi per i campi selezionati."
                statusMessage = nil
                return
            }

            QuoteStore.saveQuotes(fetchedQuotes)
            refreshFromSharedStore()

            // Salva le quote anche nel container del widget
            SharedFileConfig.save(.init(
                notionToken: notionToken.trimmingCharacters(in: .whitespacesAndNewlines),
                databaseID: databaseID.trimmingCharacters(in: .whitespacesAndNewlines),
                titlePropertyName: titlePropertyName.trimmingCharacters(in: .whitespacesAndNewlines),
                sourcePropertyName: sourcePropertyName.trimmingCharacters(in: .whitespacesAndNewlines),
                refreshIntervalSeconds: refreshIntervalSeconds,
                quotes: fetchedQuotes,
                lastSync: Date()
            ))

            statusMessage = "Sincronizzate \(fetchedQuotes.count) frasi da Notion."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }
}
