# GroceryOCR

An iOS app that extracts structured grocery ingredients from recipe images using on-device OCR.

## Product and engineering plans

- [Stabilization and test plan](docs/01-stabilization-and-test-plan.md) — reproduced build failures, dependency map, test instrumentation, CI gates, and implementation order.
- [Native iOS redesign plan](docs/02-ios-native-redesign-plan.md) — experience map, wireframes, state/data schema, native component strategy, and vertical slices.
- [Deterministic ingredient aggregation plan](docs/03-deterministic-ingredient-aggregation-plan.md) — exact OCR quantity parsing, strict grouping, unit conversion, purchase rounding, list behavior, and test fixtures.
- [Imperial shopping decision engine](docs/04-imperial-shopping-decision-engine.md) — advanced purchase-aware grouping, Imperial conversion and display, package optimization, aisle organization, explanations, and overrides.

## Contents

- `GroceryOCR/` app source
- `GroceryOCRTests/` unit tests
- `GroceryOCRUITests/` UI tests
- `GroceryOCR.xcodeproj/` Xcode project

## Current status

The current application target does not compile. The stabilization plan records the confirmed blockers and defines the repair contract. The planning branch changes documentation only; it does not alter application or test code.
