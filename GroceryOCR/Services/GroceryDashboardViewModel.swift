import Foundation
import UIKit

@MainActor
final class GroceryDashboardViewModel: ObservableObject {
    enum ScanState: Equatable {
        case idle
        case processing(progress: Int, total: Int)
        case ready
        case empty
        case failed(String)
    }

    @Published var selectedImages: [UIImage] = []
    @Published var shoppingEntries: [ShoppingListEntry] = []
    @Published var scanState: ScanState = .idle
    @Published var isPresentingImagePicker = false
    @Published var errorMessage: String?
    @Published var latestSummary: String = "Ready to scan."
    @Published var exportURL: URL?

    private let dependencies: AppDependencies
    private var processedImageHashes: Set<String> = []

    init(dependencies: AppDependencies = .live) {
        self.dependencies = dependencies
        loadStoredEntries()
    }

    var hasSelectedImages: Bool {
        !selectedImages.isEmpty
    }

    var hasStoredEntries: Bool {
        !shoppingEntries.isEmpty
    }

    var totalCount: Int {
        shoppingEntries.count
    }

    func addImages(_ images: [UIImage]) {
        selectedImages.append(contentsOf: images)
    }

    func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }

    func clearSelectedImages() {
        selectedImages.removeAll()
    }

    func scanSelectedImages() {
        guard !selectedImages.isEmpty else {
            scanState = .empty
            latestSummary = "Add a recipe image to begin."
            return
        }

        scanState = .processing(progress: 0, total: selectedImages.count)
        errorMessage = nil
        latestSummary = "Scanning \(selectedImages.count) image(s)."

        Task {
            do {
                let session = try await processCurrentImages()
                try dependencies.repository.save(session: session)
                shoppingEntries = session.shoppingEntries
                exportURL = try? dependencies.repository.exportCSVURL()
                clearSelectedImages()
                scanState = session.shoppingEntries.isEmpty ? .empty : .ready
                latestSummary = session.shoppingEntries.isEmpty
                    ? "No ingredients were recognized."
                    : "Ready with \(session.shoppingEntries.count) shopping row(s)."
            } catch {
                errorMessage = error.localizedDescription
                scanState = .failed(error.localizedDescription)
                latestSummary = "Scan failed: \(error.localizedDescription)"
            }
        }
    }

    func reloadStoredEntries() {
        loadStoredEntries()
    }

    func deleteEntry(_ entry: ShoppingListEntry) {
        do {
            try dependencies.repository.deleteEntry(withID: entry.id)
            loadStoredEntries()
            exportURL = try? dependencies.repository.exportCSVURL()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAll() {
        do {
            try dependencies.repository.clear()
            shoppingEntries.removeAll()
            selectedImages.removeAll()
            exportURL = nil
            latestSummary = "Cleared local scan history."
            scanState = .idle
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshExportURL() {
        exportURL = try? dependencies.repository.exportCSVURL()
    }

    private func loadStoredEntries() {
        do {
            shoppingEntries = try dependencies.repository.loadEntries()
            exportURL = try? dependencies.repository.exportCSVURL()
            scanState = shoppingEntries.isEmpty ? .idle : .ready
            latestSummary = shoppingEntries.isEmpty
                ? "Add a recipe image to begin."
                : "Loaded \(shoppingEntries.count) saved row(s)."
        } catch {
            errorMessage = error.localizedDescription
            shoppingEntries = []
            scanState = .failed(error.localizedDescription)
            latestSummary = "Could not load saved scans."
        }
    }

    private func processCurrentImages() async throws -> ScanSession {
        var combinedText = ""
        var hashes: [String] = []
        var failureCount = 0

        for (index, image) in selectedImages.enumerated() {
            scanState = .processing(progress: index, total: selectedImages.count)

            guard let hash = dependencies.fingerprinting.fingerprint(for: image) else {
                failureCount += 1
                continue
            }

            guard !processedImageHashes.contains(hash) else {
                continue
            }

            do {
                let recognizedText = try await dependencies.recognizer.recognizeText(from: image)
                if !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !combinedText.isEmpty {
                        combinedText += "\n"
                    }
                    combinedText += recognizedText
                    hashes.append(hash)
                    processedImageHashes.insert(hash)
                }
            } catch {
                failureCount += 1
            }
        }

        let session = dependencies.decisionEngine.buildShoppingEntries(
            from: combinedText,
            sourceImageHashes: hashes
        )

        if session.shoppingEntries.isEmpty && failureCount == selectedImages.count {
            throw NSError(domain: "GroceryOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text could be recognized from the selected images."])
        }

        return session
    }
}
