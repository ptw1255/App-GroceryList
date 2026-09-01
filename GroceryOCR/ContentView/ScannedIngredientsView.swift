//
//  ScannedIngredientsView.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import SwiftUI

struct ScannedIngredientsView: View {
    @Binding var storedScans: [String]
    var deleteItem: (String) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Scanned Ingredients")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)

            List {
                ForEach(storedScans, id: \.self) { scan in
                    HStack {
                        Text(scan)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { deleteItem(scan) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .listRowBackground(Color.black)
            }
            .scrollContentBackground(.hidden)
            .frame(height: 200)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}
