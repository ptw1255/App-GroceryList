# Deterministic ingredient aggregation plan

Status: feature specification; no production code included  
Dependencies: stabilization Phase 2 domain seams and the redesign's structured ingredient model

## Product outcome

Turn OCR-derived recipe requirements into a trustworthy shopping list without losing the original recipe quantities.

Example:

```text
½ onion + ¾ onion
Recipe demand: 1¼ onions
Shopping quantity: 2 onions
Reason: onions are purchased as whole countable items
```

The key product rule is:

> Aggregate exact recipe demand first. Apply purchase rounding once, only when projecting the final shopping-list row.

This prevents rounding each source line independently and buying too much. It also prevents nonsensical rounding of measured goods: `1.25 lb onions` remains `1.25 lb`, while `1.25 onions` becomes `2 onions`.

## Jobs to be done

1. Combine equivalent ingredients from one or more scanned recipe pages.
2. Preserve exact recipe demand and source traceability.
3. Convert compatible units deterministically.
4. Round only ingredients known to be purchased as discrete units or packages.
5. Explain every merge, conversion, and rounding decision in the list UI.
6. Ask for review instead of guessing when identity, unit compatibility, or purchase behavior is uncertain.

## Non-goals

- No probabilistic or generative model decides grouping or purchase quantity.
- No automatic store inventory, pricing, brand selection, or package-size lookup.
- No density-based mass/volume conversion unless a versioned, explicit ingredient conversion exists.
- No fuzzy merge that can silently combine different ingredients.
- No replacement of the exact recipe quantity with the rounded shopping quantity.

## Deterministic pipeline

```mermaid
flowchart LR
    OCR[Recognized lines] --> Parse[Parse exact quantities and units]
    Parse --> Normalize[Normalize names, units, and modifiers]
    Normalize --> Classify[Resolve purchase behavior]
    Classify --> Key[Build deterministic grouping key]
    Key --> Convert[Convert compatible units]
    Convert --> Sum[Sum exact recipe demand]
    Sum --> Project[Apply one purchase rule]
    Project --> Review{Confident?}
    Review -->|yes| List[Shopping-list row]
    Review -->|no| Flag[Review-required row]
    Flag --> List
```

The pipeline is pure: the same inputs, ruleset version, locale, and user overrides always produce the same ordered output and explanation trace.

## Core concepts

### Recipe demand versus shopping quantity

These must be separate fields:

| Concept | Meaning | Example |
|---|---|---|
| Recipe demand | Exact amount required by all source recipes | `1¼ onion` |
| Shopping quantity | Actionable purchase amount after applying a purchase rule | `2 onions` |
| Package plan | Optional package count when an explicit package size is known | `2 × 14 oz cans` |

Rounding a shopping quantity never mutates recipe demand.

### Quantity representation

Use an exact rational representation for parsed fractions rather than `Double`:

```text
RationalQuantity
  numerator: Int
  denominator: positive Int
```

Normalize by greatest common divisor. Parse integers, decimals, mixed numbers, ASCII fractions, and Unicode fractions into the same representation:

- `1.25`, `1 1/4`, and `1¼` → `5/4`
- `0.5` and `1/2` → `1/2`

Use `Decimal` only at serialization or display boundaries when required. This avoids binary floating-point drift in equality, grouping, and rounding tests.

### Purchase behavior

```text
PurchaseBehavior
  continuous(dimension)      // mass, volume, or another measurable amount
  discreteEach               // onion, lemon, avocado
  discretePackage(size)      // explicit 14 oz can, 12-count carton
  recipeUnit                 // bunch, sprig, clove; preserve as stated
  unknown                    // do not round; require review if fractional
```

Rules:

1. `continuous`: convert within the same dimension and retain exact aggregate demand.
2. `discreteEach`: use the mathematical ceiling of positive aggregate demand.
3. `discretePackage(size)`: calculate `ceil(aggregate demand / package size)` and retain both package count and total supplied amount.
4. `recipeUnit`: sum only identical canonical units; do not infer a conversion.
5. `unknown`: preserve exact demand. A positive fractional count receives `needsReview = true` rather than automatic rounding.

The MVP purchase catalog is a small, versioned local data file. It contains only reviewed canonical identities and behaviors. An ingredient absent from that catalog is `unknown`.

## Normalization and grouping rules

### 1. Parse without interpretation loss

Each OCR line becomes a draft containing:

- original recognized text;
- exact quantity, if recognized;
- original unit token;
- candidate ingredient name;
- preparation and purchase-relevant modifiers;
- OCR confidence and source line identity;
- parse warnings.

A partially parsed line remains reviewable. It is not silently discarded.

### 2. Canonicalize using versioned tables

Deterministic tables provide:

- singular/plural aliases: `onions` → `onion`;
- unit aliases: `tablespoons`, `tbsp`, `T` → `tablespoon` where locale-safe;
- reviewed OCR aliases: for example, a known recurrent OCR error may map to `onion`;
- preparation modifiers: `diced`, `chopped`, `divided`, `for garnish`;
- identity modifiers: `red`, `yellow`, `sweet`, `green` for onion varieties.

No general edit-distance correction automatically changes an ingredient. Unknown spellings are review-required suggestions.

### 3. Build a strict grouping key

```text
IngredientGroupingKey
  canonicalIngredientID
  identityModifiers          // sorted, purchase-relevant only
  quantityDimension          // count, mass, volume, package, recipe unit
  packageSpecification?      // size and unit when explicit
```

Preparation modifiers do not split a shopping group but remain in the source trace. Identity modifiers do split a group.

Examples:

- `1 diced onion` + `½ chopped onion` → one onion group.
- `1 red onion` + `1 yellow onion` → separate groups.
- `1 cup flour` + `100 g flour` → separate unresolved groups; no density conversion.
- `2 cloves garlic` + `1 bulb garlic` → separate groups unless an explicit reviewed conversion is introduced.

### 4. Convert only compatible units

Use a versioned conversion table with exact factors inside one dimension:

- mass ↔ mass;
- volume ↔ volume;
- count ↔ count;
- identical recipe units ↔ identical recipe units.

Never convert mass to volume from generic rules. Never convert a recipe unit such as `bunch` or `sprig` to mass/count without an ingredient-specific reviewed rule.

Choose one stable aggregate unit using a deterministic policy:

1. user-selected preferred unit, if compatible;
2. otherwise the first source unit in source order;
3. simplify for display only when the conversion is exact and does not reduce useful precision.

### 5. Sum exact demand

Sum all compatible contributions as rational values before any purchase rounding. Preserve the ordered contribution IDs in an `AggregationTrace`.

### 6. Apply one purchase projection

```text
if behavior == discreteEach and demand > 0:
    shoppingQuantity = ceil(demand)
else if behavior == discretePackage(size) and demand > 0:
    packageCount = ceil(demand / size)
else:
    shoppingQuantity = demand
```

Zero or negative quantities are invalid input and require review. The rules engine never invents a default quantity when OCR does not recognize one.

### 7. Order deterministically

Default list order is the earliest contributing source position: session creation order, page index, then line index. Ties use the canonical ingredient ID. User-reordered positions override this order and persist by stable list-item ID.

## Data schema additions

### `IngredientDemand`

| Field | Type | Purpose |
|---|---|---|
| `id` | UUID | Stable aggregate identity. |
| `groupingKey` | `IngredientGroupingKey` | Exact merge key. |
| `quantity` | `RationalQuantity?` | Exact aggregate recipe demand. |
| `unit` | `CanonicalUnit?` | Unit after compatible conversion. |
| `contributionIDs` | ordered `[IngredientContribution.ID]` | Explainability and source review. |
| `warnings` | `[AggregationWarning]` | Ambiguity or incompatible-unit flags. |
| `rulesVersion` | String | Reproducibility and migration. |

### `IngredientContribution`

| Field | Type | Purpose |
|---|---|---|
| `id` | UUID | Stable source identity. |
| `recognizedLineID` | UUID | Trace back to OCR. |
| `quantity` | `RationalQuantity?` | Exact parsed source amount. |
| `unit` | `CanonicalUnit?` | Parsed/normalized source unit. |
| `canonicalIngredientID` | String? | Reviewed dictionary identity. |
| `identityModifiers` | sorted set | Prevent unsafe merges. |
| `preparationModifiers` | ordered list | Display in details; excluded from grouping. |
| `confidence` | Float? | Review signal, not grouping logic. |

### `ShoppingListItem`

| Field | Type | Purpose |
|---|---|---|
| `id` | UUID | Stable UI identity. |
| `demandID` | UUID | Links to exact aggregate demand. |
| `shoppingQuantity` | `RationalQuantity?` | Rounded only under a known rule. |
| `shoppingUnit` | `CanonicalUnit?` | `each`, package, or continuous unit. |
| `packageCount` | Int? | Present only for explicit package sizing. |
| `purchaseBehavior` | `PurchaseBehavior` | Rule used to project demand. |
| `roundingApplied` | Bool | Enables visible explanation. |
| `needsReview` | Bool | Prevents silent guessing. |
| `userOverride` | `PurchaseOverride?` | Explicit user decision. |
| `trace` | `AggregationTrace` | Human-readable and testable decisions. |

### `PurchaseOverride`

```text
PurchaseOverride
  quantity: RationalQuantity
  unit: CanonicalUnit
  reason: userEdited | userConfirmedSuggestion | packagePreference
  createdAt: Date
  basedOnRulesVersion: String
```

An override changes the shopping projection, not source contributions or recipe demand. Reprocessing prompts the user if a changed demand makes the override potentially stale.

### `AggregationTrace`

```text
AggregationTrace
  rulesVersion: String
  sourceContributionIDs: ordered [UUID]
  canonicalizationRules: ordered [RuleID]
  conversions: ordered [from, to, exactFactor]
  aggregateDemand: quantity + unit
  purchaseRule: RuleID?
  projectedQuantity: quantity + unit
  warnings: ordered [StableWarningCode]
```

The trace is local product data. Telemetry records only counts of grouped, rounded, overridden, and review-required rows—never ingredient names or quantities.

## List experience

Yes, the purchase logic should be visible directly in the list while remaining editable.

```text
┌────────────────────────────────┐
│ 2 onions                       │
│ 1¼ needed · rounded up         │
│                            ›   │
├────────────────────────────────┤
│ 1¼ lb ground beef              │
│ exact combined amount          │
│                            ›   │
├────────────────────────────────┤
│ 1½ bunches cilantro            │
│ Check purchase quantity        │
│                            !   │
└────────────────────────────────┘
```

Row rules:

- The primary label is the actionable shopping quantity.
- Secondary text shows exact demand when rounding occurred.
- A review indicator appears only when the rules engine cannot make a safe decision.
- Tapping a row opens aggregation detail: contributions, conversions, purchase rule, and quantity override.
- Editing purchase quantity creates a `PurchaseOverride`; it does not rewrite OCR evidence.
- The export uses the shopping quantity and can optionally include exact recipe demand in separate columns.

Suggested detail presentation:

```text
Onions
Buy                         2 onions
Recipe total                1¼ onions

From scans
Page 1                      ½ onion
Page 2                      ¾ onion

Why 2?
Onions are purchased whole, so 1¼ rounds up to 2.

[ Edit purchase quantity ]
```

## Deterministic examples

| Contributions | Exact demand | Shopping projection | Reason |
|---|---:|---:|---|
| `½ onion` + `¾ onion` | `1¼ onion` | `2 onions` | Known `discreteEach`; ceiling once after sum. |
| `1 diced onion` + `½ chopped onion` | `1½ onion` | `2 onions` | Preparation does not change purchase identity. |
| `1 red onion` + `1 yellow onion` | two groups | `1 red`, `1 yellow` | Identity modifiers prevent merge. |
| `200 g flour` + `0.5 kg flour` | `700 g flour` | `700 g flour` | Compatible mass conversion; continuous goods are not integer-rounded. |
| `1 cup milk` + `8 fl oz milk` | `2 cups milk` | `2 cups milk` | Compatible volume conversion under one explicit locale. |
| `1 cup flour` + `100 g flour` | two groups | review | Mass/volume conversion needs ingredient density. |
| `1½ lemons` | `1½ lemons` | `2 lemons` | Known `discreteEach`. |
| `1.25 lb onions` | `1.25 lb onions` | `1.25 lb onions` | Mass is continuous even though onions can also be counted. |
| `1½ bunches cilantro` | `1½ bunches` | review | `bunch` is variable; no silent package rounding by default. |
| `1½ × 14 oz cans tomatoes` | `21 oz` | `2 × 14 oz cans` | Explicit package size allows ceiling package calculation. |

## Error and ambiguity rules

| Condition | Behavior |
|---|---|
| Missing quantity | Preserve item with no quantity and require review. |
| Unknown ingredient with fractional count | Preserve exact value and require review; do not round automatically. |
| Incompatible units for same ingredient | Keep separate demand groups and show a merge warning. |
| Low OCR confidence on quantity/unit/name | Keep source visible and require review before save. |
| Conflicting identity modifiers | Keep separate groups. |
| Recognized package without size | Preserve package count; do not infer size. |
| Negative or zero quantity | Mark invalid and require edit/removal. |
| Ruleset changed after user override | Preserve override and ask for confirmation if demand changed. |

## Test contract

### Unit suites

1. Quantity parser tests integers, decimals, mixed fractions, ASCII fractions, and Unicode fractions.
2. Canonicalization tests singular/plural, explicit aliases, preparation modifiers, identity modifiers, and unknown tokens.
3. Grouping-key tests prove that preparation merges and identity differences split.
4. Conversion tests cover exact compatible conversions and reject dimension crossing.
5. Aggregation tests prove commutative sums while preserving deterministic source ordering.
6. Purchase projection tests cover continuous, discrete, package, recipe-unit, unknown, zero, and missing quantities.
7. Trace tests assert the exact ordered rule IDs and calculations.
8. Override tests prove that recipe demand remains unchanged.

### Golden-table tests

Store acceptance cases as versioned, machine-readable fixtures:

```text
input recognized lines
+ locale
+ rulesVersion
+ optional overrides
= expected contributions
+ expected grouping keys
+ exact demands
+ shopping projections
+ warnings
+ ordered traces
```

Every production bug becomes a fixture before its rule changes. Updating the local catalog or conversion rules requires reviewing the golden diff and incrementing `rulesVersion`.

### Integration tests

- OCR stub → parser → aggregator → shopping-list projection → in-memory repository.
- Multiple pages with mixed confidence and one failed page.
- Reprocessing the same session produces byte-for-byte equivalent aggregate output.
- Migration from existing string ingredients produces review-required structured rows without data loss.
- CSV export contains stable order and separate `needed` and `buy` fields when rounding occurs.

### UI tests

- A seeded `½ onion + ¾ onion` flow displays `2 onions` and `1¼ needed · rounded up`.
- Aggregation detail displays both source contributions and the rule explanation.
- Editing `2 onions` to `3 onions` creates an override and leaves `1¼ needed` unchanged.
- An unknown fractional item shows review-required treatment and no automatic whole-number claim.
- Large Dynamic Type and VoiceOver communicate both the purchase quantity and rounding explanation.

## Telemetry and quality measures

Privacy-safe event fields may include:

- number of source contributions;
- number of output groups;
- number of compatible conversions;
- number of discrete round-ups;
- number of review-required groups;
- number of user overrides;
- stable warning/error codes;
- ruleset version and processing duration.

Do not emit names, quantities, units, recognized text, source images, or aggregation traces.

Useful outcome measures:

- percentage of completed scans with zero review-required groups;
- percentage of automatic round-ups later overridden;
- average groups reduced through deterministic merging;
- regression rate across the golden fixture corpus;
- aggregation duration for a fixed fixture set.

## Implementation slices

### Slice 1 — exact quantity and canonical units

- Introduce rational quantities, canonical units, modifiers, and source contributions.
- Parse common numeric forms without changing current UI behavior.
- Add the golden fixture harness and ruleset version.

Exit: every recognized line is preserved as a structured or review-required contribution.

### Slice 2 — strict deterministic grouping

- Add reviewed ingredient/unit aliases and strict grouping keys.
- Convert compatible dimensions and sum exact demand.
- Produce ordered aggregation traces and warnings.

Exit: identical fixture input produces identical grouped demand across repeated runs.

### Slice 3 — purchase projection

- Add the small versioned purchase-behavior catalog.
- Apply discrete and explicit-package ceiling rules after aggregation.
- Preserve continuous and unknown quantities without unsafe rounding.

Exit: the complete deterministic example table passes as golden tests.

### Slice 4 — list and explanation UI

- Display actionable `buy` quantity as the primary row value.
- Display exact `needed` quantity when different.
- Add review state, aggregation details, and purchase overrides.
- Add accessibility semantics and UI fixtures.

Exit: users can understand and change every automatic grouping/rounding decision.

### Slice 5 — migration, export, and release gates

- Migrate legacy string rows into reviewable contributions.
- Export exact demand and shopping quantity as distinct fields.
- Add CI golden-diff review, performance baselines, and privacy assertions.

Exit: no legacy data is lost, and a rules change cannot alter shopping quantities without an explicit fixture diff.

## Definition of done

- Exact source demand is never destroyed by shopping rounding.
- Grouping, conversion, ordering, and rounding are reproducible under a named ruleset version.
- `1.25 onions` can become `2 onions`; `1.25 lb onions` does not become `2 lb`.
- Unknown or incompatible cases are visible and editable rather than guessed.
- Every automated decision has a local explanation trace and a user override.
- Unit, golden, integration, UI, accessibility, migration, and export tests cover the feature.
- Telemetry contains no ingredient content.

