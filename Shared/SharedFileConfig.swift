import Foundation
import OSLog

/// Condivide la configurazione tra app e widget scrivendo un JSON
/// dentro il container sandbox del widget.
///
/// L'app (non sandboxed) scrive nel container del widget usando il path reale.
/// Il widget (sandboxed) legge dalla propria home che punta allo stesso container.
enum SharedFileConfig {
    struct Config: Codable {
        var notionToken: String
        var databaseID: String
        var titlePropertyName: String
        var sourcePropertyName: String
        var refreshIntervalSeconds: Int
        var quotes: [Quote]
        var lastSync: Date?
    }

    private static let logger = Logger(subsystem: "com.jonathanlamela.NotionQuotes", category: "SharedFileConfig")
    private static let widgetBundleID = "com.jonathanlamela.NotionQuotes.widget"
    private static let configRelativePath = "Library/Application Support/NotionQuotes/config.json"

    /// Home directory reale (/Users/xxx), bypassando la sandbox.
    private static var realHomeDirectory: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }

    /// Path usato dall'app (non sandboxed): scrive dentro il container del widget.
    private static var widgetContainerConfigURL: URL {
        URL(fileURLWithPath: realHomeDirectory)
            .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data")
            .appendingPathComponent(configRelativePath)
    }

    /// Path usato dal widget (sandboxed): legge dalla propria home.
    private static var sandboxedConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(configRelativePath)
    }

    /// Chiamato dall'app per scrivere dentro il container del widget.
    static func save(_ config: Config) {
        let url = widgetContainerConfigURL
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(config)
            try data.write(to: url, options: .atomic)
            logger.info("Config saved to \(url.path, privacy: .public)")
        } catch {
            logger.error("Failed to save config to \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Chiamato dal widget per leggere dalla propria home sandboxed.
    static func load() -> Config? {
        let url = sandboxedConfigURL
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(Config.self, from: data)
            logger.info("Config loaded from \(url.path, privacy: .public) — token length: \(config.notionToken.count), dbID length: \(config.databaseID.count)")
            return config
        } catch {
            logger.error("Failed to load config from \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
