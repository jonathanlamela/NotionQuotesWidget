import AppIntents
import OSLog
import SwiftUI
import WidgetKit

private let widgetLogger = Logger(subsystem: "com.jonathanlamela.NotionQuotes", category: "WidgetProvider")

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote
    let position: Int
    let total: Int
    let lastSync: Date?
    let diagnosticsMessage: String?
}

struct NotionWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configurazione Notion"
    static var description = IntentDescription("Configura direttamente il widget con token, database e campi Notion.")

    @Parameter(title: "Token Notion")
    var notionToken: String?

    @Parameter(title: "Database ID")
    var databaseID: String?

    @Parameter(title: "Campo titolo")
    var titlePropertyName: String?

    @Parameter(title: "Campo fonte")
    var sourcePropertyName: String?

    @Parameter(title: "Rotazione (secondi)")
    var refreshIntervalSeconds: Int?

    init() {
        notionToken = nil
        databaseID = nil
        titlePropertyName = "Title"
        sourcePropertyName = "Source"
        refreshIntervalSeconds = SharedConstants.defaultRefreshIntervalSeconds
    }
}

struct QuoteTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = NotionWidgetConfigurationIntent

    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(
            date: Date(),
            quote: .placeholder,
            position: 1,
            total: 1,
            lastSync: nil,
            diagnosticsMessage: "Configura il widget con token e database Notion"
        )
    }

    func snapshot(for configuration: NotionWidgetConfigurationIntent, in context: Context) async -> QuoteEntry {
        let cached = loadCachedQuotes()
        guard !cached.quotes.isEmpty else {
            return QuoteEntry(date: Date(), quote: .placeholder, position: 1, total: 1, lastSync: nil, diagnosticsMessage: cached.diagnosticsMessage)
        }
        let q = cached.quotes[0]
        return QuoteEntry(date: Date(), quote: q, position: 1, total: cached.quotes.count, lastSync: cached.lastSync, diagnosticsMessage: nil)
    }

    func timeline(for configuration: NotionWidgetConfigurationIntent, in context: Context) async -> Timeline<QuoteEntry> {
        let cached = loadCachedQuotes()
        // La cache ha la priorità perché l'intent ha sempre il default (300s) dal suo init()
        let intervalSeconds = max(
            cached.refreshIntervalSeconds ?? configuration.refreshIntervalSeconds ?? SharedConstants.defaultRefreshIntervalSeconds,
            SharedConstants.minimumRefreshIntervalSeconds
        )
        widgetLogger.error("Timeline interval: \(intervalSeconds)s (intent=\(String(describing: configuration.refreshIntervalSeconds)), cache=\(String(describing: cached.refreshIntervalSeconds)))")
        let quotes = cached.quotes
        let now = Date()

        guard !quotes.isEmpty else {
            let entry = QuoteEntry(date: now, quote: .placeholder, position: 1, total: 1, lastSync: nil, diagnosticsMessage: cached.diagnosticsMessage)
            let next = now.addingTimeInterval(60)
            return Timeline(entries: [entry], policy: .after(next))
        }

        // Genera entry multiple per ruotare le frasi senza ri-scaricare
        let maxEntries = min(quotes.count, 60) // max 60 entry per timeline
        var entries: [QuoteEntry] = []
        let startIndex = quoteIndex(for: now, count: quotes.count, intervalSeconds: intervalSeconds)

        for i in 0..<maxEntries {
            let entryDate = now.addingTimeInterval(Double(i) * Double(intervalSeconds))
            let idx = (startIndex + i) % quotes.count
            entries.append(QuoteEntry(
                date: entryDate,
                quote: quotes[idx],
                position: idx + 1,
                total: quotes.count,
                lastSync: cached.lastSync,
                diagnosticsMessage: nil
            ))
        }

        let nextRefresh = now.addingTimeInterval(Double(maxEntries) * Double(intervalSeconds))
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }

    private func quoteIndex(for date: Date, count: Int, intervalSeconds: Int) -> Int {
        guard count > 0 else { return 0 }
        let safeInterval = max(intervalSeconds, SharedConstants.minimumRefreshIntervalSeconds)
        let bucket = Int(date.timeIntervalSinceReferenceDate) / safeInterval
        return bucket % count
    }

    /// Legge le frasi dalla cache nel container del widget (scritte dall'app).
    /// NON fa fetch da Notion.
    private func loadCachedQuotes() -> (quotes: [Quote], lastSync: Date?, refreshIntervalSeconds: Int?, diagnosticsMessage: String?) {
        guard let config = SharedFileConfig.load() else {
            widgetLogger.error("No cached data available")
            return ([], nil, nil, "Apri l'app Notion Quotes, sincronizza da Notion e premi Salva")
        }

        if config.quotes.isEmpty {
            widgetLogger.error("Config loaded but no quotes cached")
            return ([], config.lastSync, config.refreshIntervalSeconds, "Nessuna frase in cache. Sincronizza da Notion nell'app.")
        }

        widgetLogger.error("Loaded \(config.quotes.count) quotes from cache, interval=\(config.refreshIntervalSeconds)s")
        return (config.quotes, config.lastSync, config.refreshIntervalSeconds, nil)
    }
}

struct NotionQuotesWidgetEntryView: View {
    var entry: QuoteTimelineProvider.Entry
    @Environment(\.widgetFamily) private var family

    private var isPlaceholder: Bool {
        entry.quote.id == Quote.placeholder.id
    }

    private var titleLineLimit: Int {
        family == .systemSmall ? 3 : 4
    }

    private var showsSource: Bool {
        family != .systemSmall
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("\u{201C}\(entry.quote.title)\u{201D}")
                    .font(family == .systemSmall ? .headline : .title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .invalidatableContent()

                if let source = entry.quote.source, !source.isEmpty, source.lowercased() != "nessuna fonte" {
                    Text(source)
                        .font(family == .systemSmall ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if isPlaceholder {
                if let diagnosticsMessage = entry.diagnosticsMessage {
                    Text(diagnosticsMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                } else {
                    Text("Apri l'app e premi Sincronizza da Notion")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct NotionQuotesWidget: Widget {
    let kind: String = SharedConstants.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NotionWidgetConfigurationIntent.self, provider: QuoteTimelineProvider()) { entry in
            NotionQuotesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Notion Quotes")
        .description("Legge direttamente da Notion e ruota le frasi senza dipendere dall'app host.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NotionQuotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        NotionQuotesWidget()
    }
}
