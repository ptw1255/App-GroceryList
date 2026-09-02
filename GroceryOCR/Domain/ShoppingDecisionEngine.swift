import Foundation

struct ShoppingDecisionEngine {
    private let recipeTextParser = RecipeTextParser()

    func buildShoppingEntries(from rawText: String, sourceImageHashes: [String]) -> ScanSession {
        let parsed = recipeTextParser.parse(rawText)
        return buildShoppingEntries(
            drafts: parsed.ingredientDrafts,
            substitutionNotes: parsed.substitutionNotes,
            ignoredLines: parsed.ignoredLines,
            sourceImageHashes: sourceImageHashes
        )
    }

    func buildShoppingEntries(
        drafts: [IngredientDraft],
        substitutionNotes: [String] = [],
        ignoredLines: [String] = [],
        sourceImageHashes: [String] = []
    ) -> ScanSession {
        let aggregated = aggregate(drafts: drafts)
        let shoppingEntries = projectShoppingEntries(from: aggregated)
        let recognizedLines = drafts.map(\.sourceText) + substitutionNotes + ignoredLines

        return ScanSession(
            createdAt: Date(),
            sourceImageHashes: sourceImageHashes,
            recognizedLines: recognizedLines,
            drafts: drafts,
            aggregatedIngredients: aggregated,
            shoppingEntries: shoppingEntries
        )
    }

    func aggregate(drafts: [IngredientDraft]) -> [AggregatedIngredient] {
        var grouped: [IngredientGroupingKey: GroupBucket] = [:]

        for draft in drafts {
            guard let quantity = draft.resolvedQuantity, !draft.canonicalName.isEmpty else { continue }
            let canonicalName = draft.canonicalName
            let mode = purchaseMode(for: draft)
            let groupingUnit = groupingUnit(for: draft, mode: mode)
            let key = IngredientGroupingKey(
                canonicalName: canonicalName,
                unit: groupingUnit,
                purchaseMode: mode,
                identityModifiers: draft.identityModifiers.sorted()
            )
            let quantityInBase = normalize(quantity: quantity, from: draft.unit, mode: mode)

            if var existing = grouped[key] {
                existing.quantity = existing.quantity + quantityInBase
                existing.sourceDraftIDs.append(draft.id)
                existing.sourceTexts.append(draft.sourceText)
                existing.needsReview = existing.needsReview || draft.needsReview || quantityInBase.denominator != 1 && mode == .recipeUnit
                grouped[key] = existing
            } else {
                grouped[key] = GroupBucket(
                    canonicalName: canonicalName,
                    displayName: draft.displayName,
                    unit: groupingUnit,
                    quantity: quantityInBase,
                    sourceDraftIDs: [draft.id],
                    sourceTexts: [draft.sourceText],
                    purchaseMode: mode,
                    needsReview: draft.needsReview || quantityInBase.denominator != 1 && mode == .recipeUnit
                )
            }
        }

        return grouped.values
            .sorted { lhs, rhs in
                let lhsOrder = lhs.sourceTexts.first?.lowercased() ?? lhs.canonicalName
                let rhsOrder = rhs.sourceTexts.first?.lowercased() ?? rhs.canonicalName
                if lhsOrder == rhsOrder {
                    return lhs.canonicalName < rhs.canonicalName
                }
                return lhsOrder < rhsOrder
            }
            .map { bucket in
                let shoppingDemand = projectDemand(bucket.quantity, mode: bucket.purchaseMode)
                let explanation = explanation(for: bucket, shoppingDemand: shoppingDemand)
                return AggregatedIngredient(
                    canonicalName: bucket.canonicalName,
                    displayName: bucket.displayName,
                    unit: bucket.unit,
                    exactDemand: bucket.quantity,
                    shoppingDemand: shoppingDemand,
                    shoppingUnit: shoppingUnit(for: bucket),
                    sourceDraftIDs: bucket.sourceDraftIDs,
                    sourceTexts: bucket.sourceTexts,
                    purchaseMode: bucket.purchaseMode,
                    needsReview: bucket.needsReview,
                    explanation: explanation
                )
            }
    }

    func projectShoppingEntries(from aggregated: [AggregatedIngredient]) -> [ShoppingListEntry] {
        aggregated
            .sorted { lhs, rhs in
                let lhsKey = lhs.sourceTexts.first?.lowercased() ?? lhs.canonicalName
                let rhsKey = rhs.sourceTexts.first?.lowercased() ?? rhs.canonicalName
                if lhsKey == rhsKey {
                    return lhs.canonicalName < rhs.canonicalName
                }
                return lhsKey < rhsKey
            }
            .map { ingredient in
                let title = ingredient.displayName.isEmpty ? ingredient.canonicalName : ingredient.displayName
                let details = details(for: ingredient)
                let badge = badge(for: ingredient)
                return ShoppingListEntry(
                    ingredient: ingredient,
                    displayTitle: title,
                    details: details,
                    badge: badge,
                    createdAt: Date()
                )
            }
    }

    private func details(for ingredient: AggregatedIngredient) -> String {
        let exact = ImperialQuantityFormatter.displayString(for: ingredient.exactDemand, unit: ingredient.unit)
        let shopping = ImperialQuantityFormatter.displayShoppingString(for: ingredient.shoppingDemand, unit: ingredient.shoppingUnit)
        if exact == shopping {
            return "Demand: \(exact)"
        }
        return "Demand: \(exact)  Buy: \(shopping)"
    }

    private func badge(for ingredient: AggregatedIngredient) -> String {
        switch ingredient.purchaseMode {
        case .looseCount:
            return "Count"
        case .looseWeight:
            return "Weight"
        case .looseVolume:
            return "Volume"
        case .recipeUnit:
            return "Recipe Unit"
        case .unknown:
            return "Review"
        }
    }

    private func explanation(for bucket: GroupBucket, shoppingDemand: RationalQuantity) -> String {
        var notes: [String] = []
        if bucket.quantity.denominator != 1 && bucket.purchaseMode == .looseCount {
            notes.append("rounded up to whole items")
        }
        if bucket.purchaseMode == .recipeUnit && bucket.quantity.denominator != 1 {
            notes.append("fractional recipe unit needs review")
        }
        if notes.isEmpty {
            notes.append("grouped deterministically")
        }
        return notes.joined(separator: "; ")
    }

    private func shoppingUnit(for bucket: GroupBucket) -> CanonicalUnit {
        switch bucket.purchaseMode {
        case .looseCount:
            return .each
        case .looseWeight:
            return .ounce
        case .looseVolume:
            return .fluidOunce
        case .recipeUnit:
            return bucket.unit
        case .unknown:
            return bucket.unit
        }
    }

    private func projectDemand(_ quantity: RationalQuantity, mode: PurchaseMode) -> RationalQuantity {
        switch mode {
        case .looseCount:
            return RationalQuantity(quantity.roundedUpToInteger())
        case .looseWeight, .looseVolume, .recipeUnit, .unknown:
            return quantity
        }
    }

    private func purchaseMode(for draft: IngredientDraft) -> PurchaseMode {
        switch draft.unit.dimension {
        case .count:
            return .looseCount
        case .mass:
            return .looseWeight
        case .volume:
            return .looseVolume
        case .recipeUnit:
            return draft.unit == .unknown ? .unknown : .recipeUnit
        }
    }

    private func groupingUnit(for draft: IngredientDraft, mode: PurchaseMode) -> CanonicalUnit {
        switch mode {
        case .looseCount:
            return .each
        case .looseWeight:
            return .ounce
        case .looseVolume:
            return .fluidOunce
        case .recipeUnit:
            return draft.unit
        case .unknown:
            return draft.unit
        }
    }

    private func normalize(quantity: RationalQuantity, from unit: CanonicalUnit, mode: PurchaseMode) -> RationalQuantity {
        switch mode {
        case .looseCount:
            return quantity
        case .looseWeight:
            return convert(quantity, from: unit, to: .ounce)
        case .looseVolume:
            return convert(quantity, from: unit, to: .fluidOunce)
        case .recipeUnit:
            return quantity
        case .unknown:
            return quantity
        }
    }

    private func convert(_ quantity: RationalQuantity, from: CanonicalUnit, to: CanonicalUnit) -> RationalQuantity {
        guard from != to else { return quantity }
        let fromFactor = baseFactor(for: from)
        let toFactor = baseFactor(for: to)
        return quantity * fromFactor / toFactor
    }

    private func baseFactor(for unit: CanonicalUnit) -> RationalQuantity {
        switch unit {
        case .each:
            return .one
        case .ounce:
            return .one
        case .pound:
            return RationalQuantity(16)
        case .teaspoon:
            return RationalQuantity(numerator: 1, denominator: 6)
        case .tablespoon:
            return RationalQuantity(numerator: 1, denominator: 2)
        case .fluidOunce:
            return .one
        case .cup:
            return RationalQuantity(8)
        case .pint:
            return RationalQuantity(16)
        case .quart:
            return RationalQuantity(32)
        case .gallon:
            return RationalQuantity(128)
        case .clove, .sprig, .bunch, .head, .can, .jar, .bottle, .bag, .box, .unknown:
            return .one
        }
    }

    private struct GroupBucket {
        var canonicalName: String
        var displayName: String
        var unit: CanonicalUnit
        var quantity: RationalQuantity
        var sourceDraftIDs: [UUID]
        var sourceTexts: [String]
        var purchaseMode: PurchaseMode
        var needsReview: Bool
    }
}
