import Foundation

struct ParsedRecipeText {
    var ingredientDrafts: [IngredientDraft]
    var substitutionNotes: [String]
    var ignoredLines: [String]
}

final class RecipeTextParser {
    private let unitAliases: [String: CanonicalUnit] = [
        "each": .each,
        "ea": .each,
        "piece": .each,
        "pieces": .each,
        "count": .each,
        "counts": .each,
        "item": .each,
        "items": .each,
        "oz": .ounce,
        "ounce": .ounce,
        "ounces": .ounce,
        "lb": .pound,
        "lbs": .pound,
        "pound": .pound,
        "pounds": .pound,
        "tsp": .teaspoon,
        "teaspoon": .teaspoon,
        "teaspoons": .teaspoon,
        "tbsp": .tablespoon,
        "tablespoon": .tablespoon,
        "tablespoons": .tablespoon,
        "fl oz": .fluidOunce,
        "floz": .fluidOunce,
        "fluid ounce": .fluidOunce,
        "fluid ounces": .fluidOunce,
        "cup": .cup,
        "cups": .cup,
        "pint": .pint,
        "pints": .pint,
        "quart": .quart,
        "quarts": .quart,
        "gallon": .gallon,
        "gallons": .gallon,
        "clove": .clove,
        "cloves": .clove,
        "sprig": .sprig,
        "sprigs": .sprig,
        "bunch": .bunch,
        "bunches": .bunch,
        "head": .head,
        "heads": .head,
        "can": .can,
        "cans": .can,
        "jar": .jar,
        "jars": .jar,
        "bottle": .bottle,
        "bottles": .bottle,
        "bag": .bag,
        "bags": .bag,
        "box": .box,
        "boxes": .box
    ]

    private let substitutionKeywords = [
        "instead of",
        "or use",
        "replace",
        "alternative",
        "substitute",
        "swap",
        "use ",
        "optional",
        "for garnish",
        "to taste",
        "as needed"
    ]

    private let preparationModifiers: Set<String> = [
        "chopped",
        "diced",
        "minced",
        "sliced",
        "grated",
        "ground",
        "softened",
        "melted",
        "divided",
        "peeled",
        "crushed",
        "rinsed",
        "drained"
    ]

    private let identityModifiers: Set<String> = [
        "red",
        "yellow",
        "green",
        "sweet",
        "small",
        "medium",
        "large",
        "fresh",
        "organic",
        "unsalted",
        "low-sodium",
        "low sodium",
        "whole",
        "skim",
        "2%",
        "1%",
        "fat-free",
        "free-range"
    ]

    func parse(_ rawText: String) -> ParsedRecipeText {
        var ingredientDrafts: [IngredientDraft] = []
        var substitutionNotes: [String] = []
        var ignoredLines: [String] = []

        let lines = rawText.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedLine.isEmpty else { continue }

            if isSubstitutionNote(cleanedLine) {
                substitutionNotes.append(cleanedLine)
                continue
            }

            if let draft = parseIngredientLine(cleanedLine, sourceIndex: index) {
                ingredientDrafts.append(draft)
            } else {
                ignoredLines.append(cleanedLine)
            }
        }

        return ParsedRecipeText(
            ingredientDrafts: ingredientDrafts,
            substitutionNotes: substitutionNotes,
            ignoredLines: ignoredLines
        )
    }

    func parseIngredientLine(_ line: String, sourceIndex: Int = 0) -> IngredientDraft? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: "–", with: "-")
        let (quantity, upperBound, remainder, warnings) = parseQuantityPrefix(in: normalized)

        var textRemainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        var unit: CanonicalUnit = .each
        var localWarnings = warnings

        if let parsedUnit = parseUnitPrefix(in: textRemainder) {
            unit = parsedUnit.unit
            textRemainder = parsedUnit.remainder
        } else if quantity != nil {
            unit = .each
        }

        let modifierSplit = splitModifiers(from: textRemainder)
        let canonicalName = normalizeIngredientName(modifierSplit.name)
        let displayName = displayIngredientName(modifierSplit.name)
        let allWarnings = localWarnings + modifierSplit.warnings

        return IngredientDraft(
            sourceText: trimmed,
            sourceIndex: sourceIndex,
            quantity: quantity,
            quantityUpperBound: upperBound,
            unit: unit,
            canonicalName: canonicalName,
            displayName: displayName,
            identityModifiers: modifierSplit.identityModifiers,
            preparationModifiers: modifierSplit.preparationModifiers,
            confidence: 1.0,
            needsReview: allWarnings.isNotEmpty || canonicalName.isEmpty || (quantity == nil && textRemainder.isEmpty),
            warnings: allWarnings
        )
    }

    private func parseQuantityPrefix(in text: String) -> (quantity: RationalQuantity?, upperBound: RationalQuantity?, remainder: String, warnings: [String]) {
        let components = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = components.first else {
            return (nil, nil, text, [])
        }

        let lowercased = first.lowercased()
        if components.count >= 3, let lower = parseSingleQuantity(components[0]), components[1] == "-", let upper = parseSingleQuantity(components[2]) {
            let remainder = components.dropFirst(3).joined(separator: " ")
            return (lower, upper, remainder, ["quantity range"])
        }

        if components.count >= 3, let lower = parseSingleQuantity(components[0]), components[1].lowercased() == "to", let upper = parseSingleQuantity(components[2]) {
            let remainder = components.dropFirst(3).joined(separator: " ")
            return (lower, upper, remainder, ["quantity range"])
        }

        if components.count >= 2, let mixed = parseMixedQuantity(components[0], components[1]) {
            let remainder = components.dropFirst(2).joined(separator: " ")
            return (mixed, nil, remainder, [])
        }

        if let value = parseSingleQuantity(first) {
            let remainder = components.dropFirst().joined(separator: " ")
            return (value, nil, remainder, [])
        }

        if let value = parseUnicodeFractionPrefix(in: text) {
            let remainder = text.dropFirst(value.consumedCharacters).description.trimmingCharacters(in: .whitespaces)
            return (value.quantity, nil, remainder, [])
        }

        if let mixed = parseCombinedNumberAndUnicodeFraction(in: text) {
            return (mixed.quantity, nil, mixed.remainder, [])
        }

        _ = lowercased
        return (nil, nil, text, [])
    }

    private func parseUnitPrefix(in text: String) -> (unit: CanonicalUnit, remainder: String)? {
        let components = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = components.first else { return nil }

        let firstTwo = components.count >= 2 ? "\(components[0].lowercased()) \(components[1].lowercased())" : nil
        if let firstTwo, let unit = unitAliases[firstTwo] {
            let remainder = components.dropFirst(2).joined(separator: " ")
            return (unit, remainder)
        }

        if let unit = unitAliases[first.lowercased()] {
            let remainder = components.dropFirst().joined(separator: " ")
            return (unit, remainder)
        }

        return nil
    }

    private func splitModifiers(from text: String) -> (name: String, identityModifiers: [String], preparationModifiers: [String], warnings: [String]) {
        let words = text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !words.isEmpty else {
            return ("", [], [], [])
        }

        var recognizedIdentityModifiers: [String] = []
        var preparationModifiersList: [String] = []
        var remaining: [String] = []

        for word in words {
            let normalizedWord = word.lowercased()
            if preparationModifiers.contains(normalizedWord) {
                preparationModifiersList.append(normalizedWord)
            } else if self.identityModifiers.contains(normalizedWord) {
                recognizedIdentityModifiers.append(normalizedWord)
            } else if normalizedWord == "freshly" || normalizedWord == "optional" {
                preparationModifiersList.append(normalizedWord)
            } else {
                remaining.append(word)
            }
        }

        if remaining.isEmpty {
            remaining = words
        }

        let display = remaining.joined(separator: " ")
        return (display, recognizedIdentityModifiers, preparationModifiersList, [])
    }

    private func isSubstitutionNote(_ line: String) -> Bool {
        let lower = line.lowercased()
        return substitutionKeywords.contains { lower.contains($0) }
    }

    private func parseSingleQuantity(_ token: String) -> RationalQuantity? {
        let cleaned = token.replacingOccurrences(of: ",", with: "")
        if let decimal = Double(cleaned), cleaned.contains(".") {
            return rational(from: decimal)
        }
        if let whole = Int(cleaned) {
            return RationalQuantity(whole)
        }
        if let unicode = unicodeFractionMap[cleaned] {
            return unicode
        }
        return nil
    }

    private func parseMixedQuantity(_ wholeToken: String, _ fractionToken: String) -> RationalQuantity? {
        guard let whole = Int(wholeToken), let fraction = parseFractionToken(fractionToken) else { return nil }
        return RationalQuantity(numerator: whole * fraction.denominator + fraction.numerator, denominator: fraction.denominator)
    }

    private func parseUnicodeFractionPrefix(in text: String) -> (quantity: RationalQuantity, consumedCharacters: Int)? {
        guard let firstCharacter = text.first, let unicode = unicodeFractionMap[String(firstCharacter)] else {
            return nil
        }
        return (unicode, 1)
    }

    private func parseCombinedNumberAndUnicodeFraction(in text: String) -> (quantity: RationalQuantity, remainder: String)? {
        guard let firstSpace = text.firstIndex(of: " ") else { return nil }
        let leading = String(text[..<firstSpace])
        let trailing = String(text[text.index(after: firstSpace)...])
        guard let whole = Int(leading), let unicode = parseUnicodeFractionPrefix(in: trailing)?.quantity else { return nil }
        let quantity = RationalQuantity(numerator: whole * unicode.denominator + unicode.numerator, denominator: unicode.denominator)
        let remainder = trailing.dropFirst(1).description
        return (quantity, remainder)
    }

    private func parseFractionToken(_ token: String) -> RationalQuantity? {
        if let unicode = unicodeFractionMap[token] {
            return unicode
        }

        let parts = token.split(separator: "/").map(String.init)
        guard parts.count == 2, let numerator = Int(parts[0]), let denominator = Int(parts[1]), denominator != 0 else {
            return nil
        }
        return RationalQuantity(numerator: numerator, denominator: denominator)
    }

    private func rational(from decimal: Double) -> RationalQuantity {
        let precision = 1_000
        let numerator = Int((decimal * Double(precision)).rounded())
        return RationalQuantity(numerator: numerator, denominator: precision)
    }

    private func normalizeIngredientName(_ text: String) -> String {
        let lower = text.lowercased()
        let cleaned = lower
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty {
            return ""
        }

        let aliases: [String: String] = [
            "onions": "onion",
            "tomatoes": "tomato",
            "potatoes": "potato",
            "berries": "berry",
            "leaves": "leaf",
            "loaves": "loaf",
            "boxes": "box",
            "buses": "bus",
            "eggs": "egg",
            "cloves": "clove",
            "sprigs": "sprig",
            "bunches": "bunch",
            "heads": "head",
            "cans": "can",
            "jars": "jar",
            "bottles": "bottle",
            "bags": "bag"
        ]

        let words = cleaned.split(separator: " ").map(String.init)
        guard var lastWord = words.last else { return cleaned }
        if let alias = aliases[lastWord] {
            lastWord = alias
        } else if lastWord.hasSuffix("ies"), lastWord.count > 3 {
            lastWord = String(lastWord.dropLast(3)) + "y"
        } else if lastWord.hasSuffix("s"), lastWord.count > 3, !lastWord.hasSuffix("ss") {
            lastWord = String(lastWord.dropLast())
        }
        var normalizedWords = words
        normalizedWords[normalizedWords.count - 1] = lastWord
        return normalizedWords.joined(separator: " ")
    }

    private func displayIngredientName(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? text : cleaned
    }

    private var unicodeFractionMap: [String: RationalQuantity] {
        [
            "¼": RationalQuantity(numerator: 1, denominator: 4),
            "½": RationalQuantity(numerator: 1, denominator: 2),
            "¾": RationalQuantity(numerator: 3, denominator: 4),
            "⅐": RationalQuantity(numerator: 1, denominator: 7),
            "⅑": RationalQuantity(numerator: 1, denominator: 9),
            "⅒": RationalQuantity(numerator: 1, denominator: 10),
            "⅓": RationalQuantity(numerator: 1, denominator: 3),
            "⅔": RationalQuantity(numerator: 2, denominator: 3),
            "⅕": RationalQuantity(numerator: 1, denominator: 5),
            "⅖": RationalQuantity(numerator: 2, denominator: 5),
            "⅗": RationalQuantity(numerator: 3, denominator: 5),
            "⅘": RationalQuantity(numerator: 4, denominator: 5),
            "⅙": RationalQuantity(numerator: 1, denominator: 6),
            "⅚": RationalQuantity(numerator: 5, denominator: 6),
            "⅛": RationalQuantity(numerator: 1, denominator: 8),
            "⅜": RationalQuantity(numerator: 3, denominator: 8),
            "⅝": RationalQuantity(numerator: 5, denominator: 8),
            "⅞": RationalQuantity(numerator: 7, denominator: 8)
        ]
    }
}

private extension Array {
    var isNotEmpty: Bool { !isEmpty }
}
