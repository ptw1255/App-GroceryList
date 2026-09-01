import SwiftUI

struct ContentView: View {
    @StateObject private var imageManager = ImageManager()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var storageManager = StorageManager()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Grocery Scanner")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    // Image Preview
                    ImageScrollView(images: $imageManager.images, removeImage: imageManager.removeImage)

                    // List of Scanned Ingredients
                    ScannedIngredientsView(storedScans: $storageManager.storedScans, deleteItem: storageManager.deleteItem)

                    Spacer()
                }
                .padding()

                // Floating Action Buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            FloatingActionButton(icon: "photo.on.rectangle", color: .green) {
                                imageManager.showImagePicker = true
                            }
                            
                            FloatingActionButton(icon: "text.viewfinder", color: .blue) {
                                ocrManager.processImages(imageManager.images, storageManager: storageManager)
                            }
                            .disabled(imageManager.images.isEmpty)

                            FloatingActionButton(icon: "square.and.arrow.up", color: .yellow) {
                                storageManager.exportCSV()
                            }
                            .disabled(storageManager.storedScans.isEmpty)

                            FloatingActionButton(icon: "trash.fill", color: .red) {
                                storageManager.clearCache()
                            }
                            .disabled(storageManager.storedScans.isEmpty)
                        }
                        .padding()
                    }
                }
            }
            .sheet(isPresented: $imageManager.showImagePicker) {
                ImagePicker(images: $imageManager.images)
            }
        }
    }
}

