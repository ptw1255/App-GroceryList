//
//  Untitled.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import SwiftUI

class ImageManager: ObservableObject {
    @Published var images: [UIImage] = []
    @Published var showImagePicker = false

    func removeImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
    }
}
