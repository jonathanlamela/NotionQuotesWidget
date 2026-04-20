import Foundation

struct Quote: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let source: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case text
        case source
    }

    init(id: String = UUID().uuidString, title: String, source: String? = nil) {
        self.id = id
        self.title = title
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decode(String.self, forKey: .text)
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(source, forKey: .source)
    }

    static let placeholder = Quote(
        id: "placeholder",
        title: "Sincronizza l'app con Notion per vedere qui le tue frasi.",
        source: "Notion Quotes"
    )
}
