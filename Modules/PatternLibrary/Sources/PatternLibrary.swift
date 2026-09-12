import Foundation

private struct PatternCatalogEntry: Decodable {
    let id: String
    let displayName: String
    let category: String
    let fileName: String
}

/// Loads the bundled catalog of built-in patterns at launch, parsing each
/// entry's `.rle` file via `RLEParser`.
final class PatternLibrary {
    private(set) var patterns: [Pattern] = []
    private(set) var categories: [String: [Pattern]] = [:]
    private(set) var categoryOrder: [String] = []

    init(bundle: Bundle) {
        guard let catalogURL = Self.url(bundle: bundle, resource: "catalog", ext: "json") else { return }
        guard let data = try? Data(contentsOf: catalogURL),
              let entries = try? JSONDecoder().decode([PatternCatalogEntry].self, from: data) else { return }

        for entry in entries {
            guard let fileURL = Self.url(bundle: bundle, resource: entry.fileName, ext: "rle"),
                  let text = try? String(contentsOf: fileURL, encoding: .utf8),
                  let pattern = try? RLEParser.parse(text, name: entry.displayName) else { continue }

            patterns.append(pattern)
            if categories[entry.category] == nil {
                categoryOrder.append(entry.category)
            }
            categories[entry.category, default: []].append(pattern)
        }
    }

    private static func url(bundle: Bundle, resource: String, ext: String) -> URL? {
        bundle.url(forResource: resource, withExtension: ext, subdirectory: "BuiltInPatterns")
            ?? bundle.url(forResource: resource, withExtension: ext)
    }
}
