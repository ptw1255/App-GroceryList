//
//  FloatingActionButton.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import SwiftUI

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding()
                .background(color)
                .clipShape(Circle())
                .shadow(radius: 10)
        }
    }
}
