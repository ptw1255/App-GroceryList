import Foundation

protocol IngredientRepository {
    func loadEntries() throws -> [ShoppingListEntry]
    func save(session: ScanSession) throws
    func deleteEntry(withID id: UUID) throws
    func clear() throws
    func exportCSVURL() throws -> URL
}

final class LocalIngredientRepository: IngredientRepository {
    private let fileManager: FileManager
    private let storeURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let resolvedBaseDirectory = baseDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderURL = resolvedBaseDirectory.appendingPathComponent("GroceryOCR", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        self.storeURL = folderURL.appendingPathComponent("scan-state.json")
    }

    func loadEntries() throws -> [ShoppingListEntry] {
        guard let data = try? Data(contentsOf: storeURL) else {
            return []
        }
        let snapshot = try JSONDecoder().decode(IngredientStoreSnapshot.self, from: data)
        return snapshot.sessions.last?.shoppingEntries ?? []
    }

    func save(session: ScanSession) throws {
        let snapshot = IngredientStoreSnapshot(sessions: [session])
        let data = try JSONEncoder.prettyPrinted.encode(snapshot)
        try data.write(to: storeURL, options: [.atomic])
    }

    func deleteEntry(withID id: UUID) throws {
        var snapshot = try loadSnapshot()
        guard var latest = snapshot.sessions.popLast() else { return }
        latest.shoppingEntries.removeAll { $0.id == id }
        latest.aggregatedIngredients.removeAll { entry in
            !latest.shoppingEntries.contains(where: { $0.ingredient.id == entry.id })
        }
        snapshot.sessions = [latest]
        try save(snapshot: snapshot)
    }

    func clear() throws {
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.removeItem(at: storeURL)
        }
    }

    func exportCSVURL() throws -> URL {
        let entries = try loadEntries()
        let exportURL = storeURL.deletingLastPathComponent().appendingPathComponent("grocery-ocr-shopping-list.csv")
        let lines = csvLines(for: entries)
        try lines.joined(separator: "\n").write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }

    private func loadSnapshot() throws -> IngredientStoreSnapshot {
        guard let data = try? Data(contentsOf: storeURL) else {
            return IngredientStoreSnapshot(sessions: [])
        }
        return try JSONDecoder().decode(IngredientStoreSnapshot.self, from: data)
    }

    private func save(snapshot: IngredientStoreSnapshot) throws {
        let data = try JSONEncoder.prettyPrinted.encode(snapshot)
        try data.write(to: storeURL, options: [.atomic])
    }

    private func csvLines(for entries: [ShoppingListEntry]) -> [String] {
        var rows = ["name,exact_demand,shopping_demand,badge,notes"]
        for entry in entries {
            let ingredient = entry.ingredient
            let exact = ImperialQuantityFormatter.displayString(for: ingredient.exactDemand, unit: ingredient.unit)
            let shopping = ImperialQuantityFormatter.displayShoppingString(for: ingredient.shoppingDemand, unit: ingredient.shoppingUnit)
            rows.append([
                csvEscape(entry.displayTitle),
                csvEscape(exact),
                csvEscape(shopping),
                csvEscape(entry.badge),
                csvEscape(ingredient.explanation)
            ].joined(separator: ","))
        }
        return rows
    }

    private func csvEscape(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var prettyPrinted: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
