import Foundation
import SwiftUI

final class StorageManager: ObservableObject {
    @Published var storedScans: [String] = []
    @Published var exportURL: URL?

    private let repository: IngredientRepository
    private var currentEntries: [ShoppingListEntry] = []

    init(repository: IngredientRepository = LocalIngredientRepository()) {
        self.repository = repository
        refreshStoredScans()
    }

    func deleteItem(_ scan: String) {
        if let entry = currentEntries.first(where: { $0.displayTitle == scan || $0.details == scan }) {
            try? repository.deleteEntry(withID: entry.id)
            refreshStoredScans()
        }
    }

    func clearCache() {
        try? repository.clear()
        refreshStoredScans()
    }

    func exportCSV() {
        exportURL = try? repository.exportCSVURL()
    }

    func refreshStoredScans() {
        currentEntries = (try? repository.loadEntries()) ?? []
        storedScans = currentEntries.map { $0.details }
        exportURL = try? repository.exportCSVURL()
    }
}
