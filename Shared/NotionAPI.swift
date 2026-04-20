import Foundation

enum NotionAPIError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int, message: String)
    case invalidPayload
    case missingField(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL Notion non valido."
        case let .requestFailed(statusCode, message):
            return "Notion ha risposto con errore \(statusCode): \(message)"
        case .invalidPayload:
            return "La risposta di Notion non contiene dati validi."
        case let .missingField(fieldName):
            return "Il campo Notion '\(fieldName)' non esiste o non contiene un testo valido."
        }
    }
}

struct NotionAPI {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchQuotes(token: String, databaseID: String, titlePropertyName: String, sourcePropertyName: String) async throws -> [Quote] {
        guard let url = URL(string: "https://api.notion.com/v1/databases/\(databaseID)/query") else {
            throw NotionAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["page_size": 100])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionAPIError.invalidPayload
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = Self.extractErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw NotionAPIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try Self.extractQuotes(from: data, titlePropertyName: titlePropertyName, sourcePropertyName: sourcePropertyName)
    }

    private static func extractQuotes(from data: Data, titlePropertyName: String, sourcePropertyName: String) throws -> [Quote] {
        guard
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = payload["results"] as? [[String: Any]]
        else {
            throw NotionAPIError.invalidPayload
        }

        if let firstProperties = results.first?["properties"] as? [String: Any] {
            guard firstProperties[titlePropertyName] != nil else {
                throw NotionAPIError.missingField(titlePropertyName)
            }
            guard firstProperties[sourcePropertyName] != nil else {
                throw NotionAPIError.missingField(sourcePropertyName)
            }
        }

        let quotes = results.compactMap { page -> Quote? in
            guard
                let properties = page["properties"] as? [String: Any],
                let titleProperty = properties[titlePropertyName] as? [String: Any],
                let title = extractText(from: titleProperty),
                !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            let sourceProperty = properties[sourcePropertyName] as? [String: Any]
            let source = sourceProperty.flatMap { extractText(from: $0) }
            let trimmedSource = source?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalSource = (trimmedSource?.isEmpty == false) ? trimmedSource : nil

            let pageID = page["id"] as? String ?? UUID().uuidString
            return Quote(id: pageID, title: title, source: finalSource)
        }

        return quotes
    }

    private static func extractText(from property: [String: Any]) -> String? {
        if let richText = property["rich_text"] as? [[String: Any]] {
            let text = richText.compactMap { $0["plain_text"] as? String }.joined()
            if !text.isEmpty {
                return text
            }
        }

        if let title = property["title"] as? [[String: Any]] {
            let text = title.compactMap { $0["plain_text"] as? String }.joined()
            if !text.isEmpty {
                return text
            }
        }

        if
            let formula = property["formula"] as? [String: Any],
            let text = formula["string"] as? String,
            !text.isEmpty
        {
            return text
        }

        return nil
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let message = payload["message"] as? String {
            return message
        }

        return nil
    }
}
