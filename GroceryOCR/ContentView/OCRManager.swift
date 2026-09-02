import Foundation
import CryptoKit
import UIKit

final class OCRManager: ObservableObject {
    @Published var processedImageHashes: Set<String> = []

    func processImages(_ images: [UIImage], storageManager: StorageManager) {
        let newImages = images.filter { image in
            guard let hash = generateImageHash(image) else { return false }
            if processedImageHashes.contains(hash) {
                return false
            }
            processedImageHashes.insert(hash)
            return true
        }

        guard !newImages.isEmpty else { return }

        OCRService().processImages(newImages) {
            storageManager.refreshStoredScans()
        }
    }

    private func generateImageHash(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return nil }
        let hash = SHA256.hash(data: imageData)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
