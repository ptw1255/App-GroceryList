//
//  IngredientAggregator.swift
//  GroceryOCR
//
//  Created by Parker Wall on 2/12/25.
//
// STEPS:
// 1: Parse Ingredients (identify, quantity, unit, and item)
// 2: Group by ingredient name -> Sum quantities of duplicate items.
// 3: Convert units if needed → Ensure "1 cup + 8 oz" converts correctly.
// 4: Result == Return a clean, aggregated list.
//
import Foundation

/// Represents a structured ingredient with a quantity, unit, and name
struct Ingredient {
    var quantity: Double
    var unit: String
    var name: String
}

class IngredientAggregator {
    /// Converts a raw ingredient string into a structured `Ingredient` object
    static func parseIngredient(_ rawText: String) -> Ingredient? {
        let pattern = #"^(\d+(\.\d+)?)\s*(cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|oz|ounce|ounces|g|gram|grams|kg|kilogram|kilograms|ml|milliliter|milliliters|l|liter|liters|lb|pound|pounds)?\s+(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: rawText.utf16.count)) else {
            return nil
        }

        let nsText = rawText as NSString
        let quantity = Double(nsText.substring(with: match.range(at: 1))) ?? 0.0
        let unit = match.range(at: 3).location != NSNotFound ? nsText.substring(with: match.range(at: 3)) : ""
        let name = nsText.substring(with: match.range(at: 4))

        return Ingredient(quantity: quantity, unit: unit, name: name)
    }

    /// Combines ingredients with the same name and unit
    static func aggregate(ingredients: [String]) -> [String] {
        var ingredientMap: [String: Ingredient] = [:]

        for rawText in ingredients {
            if let ingredient = parseIngredient(rawText) {
                let key = "\(ingredient.name.lowercased())_\(ingredient.unit.lowercased())"

                if var existingIngredient = ingredientMap[key] {
                    existingIngredient.quantity += ingredient.quantity
                    ingredientMap[key] = existingIngredient
                } else {
                    ingredientMap[key] = ingredient
                }
            }
        }

        return ingredientMap.values.map { ingredient in
            let quantityString = ingredient.quantity.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", ingredient.quantity)
                : String(ingredient.quantity)
            return "\(quantityString) \(ingredient.unit) \(ingredient.name)"
        }
    }
}
