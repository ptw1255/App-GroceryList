import Foundation

struct AppDependencies {
    let recognizer: TextRecognizing
    let fingerprinting: ImageFingerprinting
    let decisionEngine: ShoppingDecisionEngine
    let repository: IngredientRepository

    static let live = AppDependencies(
        recognizer: VisionTextRecognizer(),
        fingerprinting: SHA256ImageFingerprinting(),
        decisionEngine: ShoppingDecisionEngine(),
        repository: LocalIngredientRepository()
    )
}

