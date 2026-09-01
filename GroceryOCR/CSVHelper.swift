//
//  CSVHelper.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
import Foundation
import UIKit

class CSVHelper {
    static let csvFileName = "scanned_ingredients.csv"

    /// Loads previously scanned text from UserDefaults
    static func loadScannedText() -> [String] {
        if let savedData = UserDefaults.standard.array(forKey: "scannedText") as? [String] {
            return savedData
        }
        return []
    }

    /// Saves a new scanned ingredient to local storage and updates the CSV file
    static func saveScannedText(_ newText: String) {
        var savedData = loadScannedText()
        savedData.append(newText)
        saveToUserDefaults(data: savedData)
        saveToCSV(data: savedData)
    }

    /// Saves updated scanned text to UserDefaults
    static func saveToUserDefaults(data: [String]) {
        UserDefaults.standard.set(data, forKey: "scannedText")
    }

    /// Writes scanned data to a CSV file
    static func saveToCSV(data: [String]) {
        let csvText = data.joined(separator: "\n")
        let fileURL = getDocumentsDirectory().appendingPathComponent(csvFileName)
        
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save CSV: \(error)")
        }
    }

    /// Clears all stored scanned ingredients and removes the CSV file
    static func clearStoredData() {
        UserDefaults.standard.removeObject(forKey: "scannedText")
        
        let fileURL = getDocumentsDirectory().appendingPathComponent(csvFileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to delete CSV file: \(error)")
        }
    }

    /// Deletes a single ingredient from the stored list
    static func deleteSpecificItem(item: String) {
        var storedItems = loadScannedText()
        storedItems.removeAll { $0 == item }
        saveToUserDefaults(data: storedItems)
        saveToCSV(data: storedItems)
    }

    /// Retrieves the app's document directory
    private static func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

extension CSVHelper {
    /// Exports the CSV file using the iOS share sheet
    static func exportCSV(from viewController: UIViewController) {
        let fileURL = getDocumentsDirectory().appendingPathComponent(csvFileName)
        
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}
