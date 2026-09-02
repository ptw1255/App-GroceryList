import Foundation
import CryptoKit
import UIKit
@preconcurrency import Vision

protocol TextRecognizing {
    func recognizeText(from image: UIImage) async throws -> String
}

struct VisionTextRecognizer: TextRecognizing {
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            return ""
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let lines = (request.results as? [VNRecognizedTextObservation])?.compactMap {
                    $0.topCandidates(1).first?.string
                } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

protocol ImageFingerprinting {
    func fingerprint(for image: UIImage) -> String?
}

struct SHA256ImageFingerprinting: ImageFingerprinting {
    func fingerprint(for image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return nil }
        let digest = SHA256.hash(data: imageData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
