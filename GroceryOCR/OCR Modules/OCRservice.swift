//
//  OCRservice.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import UIKit

class OCRService {
    let visionOCR = VisionOCR()
    let textProcessor = TextProcessor()
    
    /// Processes an array of images: extracts raw text from each,
    /// then processes the combined text, and finally saves the results.
    func processImages(_ images: [UIImage], completion: @escaping () -> Void) {
        print("OCRService - processImages() started with \(images.count) images")
        var rawTextCombined = ""
        let dispatchGroup = DispatchGroup()
        
        for image in images {
            dispatchGroup.enter()
            visionOCR.extractText(from: image) { extractedText in
                if let text = extractedText {
                    rawTextCombined += "\n" + text
                }
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: .main) {
            print("OCRService - Raw OCR text:", rawTextCombined)
            
            // Step 1: Process extracted text (filter for valid ingredients)
            let processedData = self.textProcessor.process(rawTextCombined)
            
            print("OCRService - Extracted Ingredients:", processedData.ingredients)
            
            // Step 2: Aggregate & deduplicate ingredients
            let aggregatedList = IngredientAggregator.aggregate(ingredients: processedData.ingredients)
            
            print("OCRService - Aggregated Ingredients:", aggregatedList)
            
            // Step 3: Save cleaned ingredient list
            for ingredient in aggregatedList {
                CSVHelper.saveScannedText(ingredient)
            }
            completion()
        }
    }
}

