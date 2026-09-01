//
//  StorageManager.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import SwiftUI

class StorageManager: ObservableObject {
    @Published var storedScans: [String] = CSVHelper.loadScannedText()

    func deleteItem(_ scan: String) {
        storedScans.removeAll { $0 == scan }
        CSVHelper.saveToUserDefaults(data: storedScans)
        CSVHelper.saveToCSV(data: storedScans)
    }

    func clearCache() {
        CSVHelper.clearStoredData()
        storedScans = []
    }

    func exportCSV() {
        if let rootVC = UIApplication.rootViewController {
            CSVHelper.exportCSV(from: rootVC)
        }
    }

    func refreshStoredScans() {
        storedScans = CSVHelper.loadScannedText()
    }
}

