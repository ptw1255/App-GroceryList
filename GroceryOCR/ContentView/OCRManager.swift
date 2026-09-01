//
//  OCRManager.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import SwiftUI

class OCRManager: ObservableObject {
    @Published var processedImageHashes: Set<String> = []

    func processImages(_ images: [UIImage], storageManager: StorageManager) {
        var newImagesToProcess: [UIImage] = []

        for image in images {
            if let hash = generateImageHash(image), !processedImageHashes.contains(hash) {
                newImagesToProcess.append(image)
                processedImageHashes.insert(hash)
            }
        }

        if newImagesToProcess.isEmpty { return }

        let ocrService = OCRService()
        ocrService.processImages(newImagesToProcess) {
            storageManager.refreshStoredScans()
        }
    }

    private func generateImageHash(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return nil }
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

