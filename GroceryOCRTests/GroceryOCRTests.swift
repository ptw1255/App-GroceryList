import Foundation
import Testing
@testable import GroceryOCR

struct GroceryOCRTests {
    @Test func parserSeparatesModifiersAndFractions() throws {
        let parser = RecipeTextParser()
        let parsed = parser.parse("""
        1 1/4 cups flour
        1 red onion
        1 diced onion
        1 chopped onion
        instead of butter use oil
        """)

        #expect(parsed.ingredientDrafts.count == 4)
        #expect(parsed.substitutionNotes.count == 1)

        let flour = try #require(parsed.ingredientDrafts.first { $0.canonicalName == "flour" })
        #expect(flour.quantity == RationalQuantity(numerator: 5, denominator: 4))
        #expect(flour.unit == .cup)

        let redOnion = try #require(parsed.ingredientDrafts.first { $0.identityModifiers.contains("red") })
        #expect(redOnion.canonicalName == "onion")
        #expect(redOnion.preparationModifiers.isEmpty)

        let dicedOnion = try #require(parsed.ingredientDrafts.first { $0.preparationModifiers.contains("diced") })
        #expect(dicedOnion.canonicalName == "onion")
        #expect(dicedOnion.identityModifiers.isEmpty)
    }

    @Test func engineGroupsDeterministicallyAndRoundsCounts() throws {
        let engine = ShoppingDecisionEngine()
        let session = engine.buildShoppingEntries(from: """
        1 1/4 onions
        1 1/4 lb onions
        1 red onion
        1 diced onion
        1 chopped onion
        """, sourceImageHashes: ["fixture-hash"])

        #expect(session.aggregatedIngredients.count == 3)

        let countOnion = try #require(session.aggregatedIngredients.first { $0.purchaseMode == .looseCount && $0.canonicalName == "onion" && $0.exactDemand == RationalQuantity(numerator: 13, denominator: 4) })
        #expect(countOnion.shoppingDemand == RationalQuantity(4))
        #expect(countOnion.shoppingUnit == .each)

        let weightOnion = try #require(session.aggregatedIngredients.first { $0.purchaseMode == .looseWeight })
        #expect(weightOnion.exactDemand == RationalQuantity(20))
        #expect(weightOnion.shoppingDemand == RationalQuantity(20))
        #expect(ImperialQuantityFormatter.displayShoppingString(for: weightOnion.shoppingDemand, unit: weightOnion.shoppingUnit) == "1 lb 4 oz")

        let redOnion = try #require(session.aggregatedIngredients.first { $0.sourceTexts.contains("1 red onion") })
        #expect(redOnion.needsReview == false)
        #expect(redOnion.explanation.contains("grouped deterministically"))
    }

    @Test func repositoryRoundTripsAndExportsCSV() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: baseURL) }

        let repository = LocalIngredientRepository(baseDirectory: baseURL)
        let engine = ShoppingDecisionEngine()
        let session = engine.buildShoppingEntries(from: """
        2 apples
        1 1/4 onions
        """, sourceImageHashes: ["hash-1"])

        try repository.save(session: session)

        let entries = try repository.loadEntries()
        #expect(entries.count == 2)

        let csvURL = try repository.exportCSVURL()
        let csv = try String(contentsOf: csvURL, encoding: .utf8)
        #expect(csv.contains("apple"))
        #expect(csv.contains("exact_demand"))
        #expect(csv.contains("2 each"))
    }
}
