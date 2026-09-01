import SwiftUI

struct HashListView: View {
    @Binding var processedImageHashes: Set<String>

    var body: some View {
        VStack {
            Text("Processed Image Hashes")
                .font(.title2)
                .bold()
                .padding()

            if processedImageHashes.isEmpty {
                Text("No processed images yet.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List {
                    ForEach(processedImageHashes.sorted(), id: \.self) { hash in
                        HStack {
                            Text(hash.prefix(12) + "...") // Show only first 12 characters
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.gray)

                            Spacer()

                            Button(action: {
                                removeHash(hash)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }

            // Clear all hashes button
            Button("Clear All") {
                processedImageHashes.removeAll()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }

    /// Removes a specific hash from session tracking.
    private func removeHash(_ hash: String) {
        processedImageHashes.remove(hash)
    }
}


