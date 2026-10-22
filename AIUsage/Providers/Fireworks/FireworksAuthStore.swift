import Foundation

struct FireworksAuth: Equatable, Sendable {
    let apiKey: String
    let accountID: String?
}

struct FireworksAuthStore: Sendable {
    static let authPath = "~/.fireworks/auth.ini"

    let files: TextFileAccessing

    init(files: TextFileAccessing = LocalTextFileAccessor()) {
        self.files = files
    }

    func load() -> FireworksAuth? {
        guard files.exists(Self.authPath),
              let text = try? files.readText(Self.authPath) else {
            return nil
        }
        let values = Self.parse(text)
        guard let apiKey = values["api_key"] else { return nil }
        return FireworksAuth(
            apiKey: apiKey,
            accountID: values["account_id"].map(Self.normalizedAccountID)
        )
    }

    /// Reads `key = value` lines written by `firectl`, with or without
    /// section headers. The first non-empty value for each key wins.
    static func parse(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty,
                  !line.hasPrefix("#"),
                  !line.hasPrefix(";"),
                  !line.hasPrefix("["),
                  let separator = line.firstIndex(where: { $0 == "=" || $0 == ":" })
            else {
                continue
            }
            let key = line[..<separator]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
                .replacingOccurrences(of: "-", with: "_")
            var value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               let first = value.first,
               first == "\"" || first == "'",
               value.last == first {
                value = String(value.dropFirst().dropLast())
            }
            guard !value.isEmpty, values[key] == nil else { continue }
            values[key] = value
        }
        return values
    }

    static func normalizedAccountID(_ value: String) -> String {
        var id = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.hasPrefix("accounts/") {
            id.removeFirst("accounts/".count)
        }
        return id.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
