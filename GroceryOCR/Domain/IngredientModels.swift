import Foundation

struct IngredientDraft: Identifiable, Codable, Hashable {
    var id = UUID()
    var sourceText: String
    var sourceIndex: Int
    var quantity: RationalQuantity?
    var quantityUpperBound: RationalQuantity?
    var unit: CanonicalUnit
    var canonicalName: String
    var displayName: String
    var identityModifiers: [String]
    var preparationModifiers: [String]
    var confidence: Double
    var needsReview: Bool
    var warnings: [String]
}

struct AggregatedIngredient: Identifiable, Codable, Hashable {
    var id = UUID()
    var canonicalName: String
    var displayName: String
    var unit: CanonicalUnit
    var exactDemand: RationalQuantity
    var shoppingDemand: RationalQuantity
    var shoppingUnit: CanonicalUnit
    var sourceDraftIDs: [UUID]
    var sourceTexts: [String]
    var purchaseMode: PurchaseMode
    var needsReview: Bool
    var explanation: String
}

enum PurchaseMode: String, Codable, Hashable {
    case looseCount
    case looseWeight
    case looseVolume
    case recipeUnit
    case unknown
}

struct ShoppingListEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var ingredient: AggregatedIngredient
    var displayTitle: String
    var details: String
    var badge: String
    var createdAt: Date
}

struct ScanSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt: Date
    var sourceImageHashes: [String]
    var recognizedLines: [String]
    var drafts: [IngredientDraft]
    var aggregatedIngredients: [AggregatedIngredient]
    var shoppingEntries: [ShoppingListEntry]
}

struct IngredientStoreSnapshot: Codable, Hashable {
    var sessions: [ScanSession]
}

struct IngredientGroupingKey: Hashable {
    var canonicalName: String
    var unit: CanonicalUnit
    var purchaseMode: PurchaseMode
    var identityModifiers: [String]
}

extension IngredientDraft {
    var resolvedQuantity: RationalQuantity? {
        quantityUpperBound ?? quantity
    }
}
