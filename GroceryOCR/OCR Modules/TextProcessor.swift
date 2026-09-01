//
//  TextProcessor.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
import Foundation

class TextProcessor {
    /// Processes raw text to extract structured ingredients and substitutions.
    func process(_ rawText: String) -> (ingredients: [String], substitutions: [String]) {
        var ingredients = [String]()
        var substitutions = [String]()
        var tempIngredient: String? = nil

        let lines = rawText.components(separatedBy: "\n")
        for line in lines {
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if cleanedLine.isEmpty { continue } // Skip empty lines

            if isValidIngredientFormat(cleanedLine) {
                if let existingIngredient = tempIngredient {
                    ingredients.append(existingIngredient) // Save previous ingredient
                }
                tempIngredient = cleanedLine // Start a new ingredient
            } else if let existingIngredient = tempIngredient, isLikelyContinuation(cleanedLine) {
                tempIngredient = existingIngredient + " " + cleanedLine // Merge with previous line
            } else if isSubstitutionNote(cleanedLine) {
                substitutions.append(cleanedLine)
            } else {
                tempIngredient = nil // Reset if it's unrelated text
            }
        }

        // Save the last ingredient if it's valid
        if let validIngredient = tempIngredient {
            ingredients.append(validIngredient)
        }

        print("TextProcessor - Extracted Ingredients:", ingredients)
        print("TextProcessor - Extracted Substitutions:", substitutions)

        return (ingredients, substitutions)
    }

    /// Checks if a line looks like a valid ingredient (number + unit + ingredient name).
    private func isValidIngredientFormat(_ line: String) -> Bool {
        let pattern = #"^\d+(\.\d+)?\s*(cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|oz|ounce|ounces|g|gram|grams|kg|kilogram|kilograms|ml|milliliter|milliliters|l|liter|liters|lb|pound|pounds)?\s+[a-zA-Z\s-]+$"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    /// Determines if a line is likely a continuation of an ingredient.
    private func isLikelyContinuation(_ line: String) -> Bool {
        let firstWord = line.components(separatedBy: " ").first ?? ""
        let isLowercased = firstWord == firstWord.lowercased()
        let isShort = line.count < 20 // Most continuation lines are short
        return isLowercased || isShort
    }

    /// Identifies substitution notes based on key phrases.
    private func isSubstitutionNote(_ line: String) -> Bool {
        let keywords = ["instead of", "or use", "replace", "alternative", "substitute", "swap", "use"]
        return keywords.contains { line.lowercased().contains($0) }
    }
}

