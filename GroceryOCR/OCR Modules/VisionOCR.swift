//
//  VisionOCR.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import UIKit
import Vision

class VisionOCR {
    /// Extracts raw text from a single image using the Vision framework.
    func extractText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            print("VisionOCR - Failed to get CGImage from UIImage")
            completion(nil)
            return
        }
        
        print("VisionOCR - Extracting text from image")
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("VisionOCR - OCR failed with error:", error.localizedDescription)
                completion(nil)
                return
            }
            
            guard let results = request.results as? [VNRecognizedTextObservation] else {
                print("VisionOCR - No text detected")
                completion(nil)
                return
            }
            
            let extractedText = results.compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            
            print("VisionOCR - Extracted Text:", extractedText.isEmpty ? "No text found" : extractedText)
            completion(extractedText)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("VisionOCR - Error performing OCR:", error.localizedDescription)
            completion(nil)
        }
    }
}
