//
//  ImageScrollVierw.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import SwiftUI
import UIKit

struct ImageScrollView: View {
    @Binding var images: [UIImage]
    var removeImage: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(images.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: images[index])
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(10)

                        Button(action: { removeImage(index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .offset(x: -5, y: 5)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
