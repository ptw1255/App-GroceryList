import Foundation

enum QuantityDimension: String, Codable, Hashable {
    case count
    case mass
    case volume
    case recipeUnit
}

enum CanonicalUnit: String, Codable, CaseIterable, Hashable {
    case each
    case ounce
    case pound
    case teaspoon
    case tablespoon
    case fluidOunce
    case cup
    case pint
    case quart
    case gallon
    case clove
    case sprig
    case bunch
    case head
    case can
    case jar
    case bottle
    case bag
    case box
    case unknown

    var dimension: QuantityDimension {
        switch self {
        case .each:
            return .count
        case .ounce, .pound:
            return .mass
        case .teaspoon, .tablespoon, .fluidOunce, .cup, .pint, .quart, .gallon:
            return .volume
        case .clove, .sprig, .bunch, .head, .can, .jar, .bottle, .bag, .box:
            return .recipeUnit
        case .unknown:
            return .recipeUnit
        }
    }

    var displayName: String {
        switch self {
        case .each:
            return "each"
        case .ounce:
            return "oz"
        case .pound:
            return "lb"
        case .teaspoon:
            return "tsp"
        case .tablespoon:
            return "tbsp"
        case .fluidOunce:
            return "fl oz"
        case .cup:
            return "cup"
        case .pint:
            return "pint"
        case .quart:
            return "quart"
        case .gallon:
            return "gallon"
        case .clove:
            return "clove"
        case .sprig:
            return "sprig"
        case .bunch:
            return "bunch"
        case .head:
            return "head"
        case .can:
            return "can"
        case .jar:
            return "jar"
        case .bottle:
            return "bottle"
        case .bag:
            return "bag"
        case .box:
            return "box"
        case .unknown:
            return "unit"
        }
    }
}

struct RationalQuantity: Codable, Hashable, Comparable {
    var numerator: Int
    var denominator: Int

    init(numerator: Int, denominator: Int) {
        precondition(denominator != 0, "Denominator cannot be zero")
        let normalized = RationalQuantity.normalized(numerator: numerator, denominator: denominator)
        self.numerator = normalized.numerator
        self.denominator = normalized.denominator
    }

    init(_ integer: Int) {
        self.init(numerator: integer, denominator: 1)
    }

    var isWholeNumber: Bool {
        denominator == 1
    }

    var isZero: Bool {
        numerator == 0
    }

    var doubleValue: Double {
        Double(numerator) / Double(denominator)
    }

    static let zero = RationalQuantity(0)
    static let one = RationalQuantity(1)

    static func < (lhs: RationalQuantity, rhs: RationalQuantity) -> Bool {
        lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
    }

    static func + (lhs: RationalQuantity, rhs: RationalQuantity) -> RationalQuantity {
        RationalQuantity(
            numerator: lhs.numerator * rhs.denominator + rhs.numerator * lhs.denominator,
            denominator: lhs.denominator * rhs.denominator
        )
    }

    static func - (lhs: RationalQuantity, rhs: RationalQuantity) -> RationalQuantity {
        RationalQuantity(
            numerator: lhs.numerator * rhs.denominator - rhs.numerator * lhs.denominator,
            denominator: lhs.denominator * rhs.denominator
        )
    }

    static func * (lhs: RationalQuantity, rhs: RationalQuantity) -> RationalQuantity {
        RationalQuantity(
            numerator: lhs.numerator * rhs.numerator,
            denominator: lhs.denominator * rhs.denominator
        )
    }

    static func / (lhs: RationalQuantity, rhs: RationalQuantity) -> RationalQuantity {
        RationalQuantity(
            numerator: lhs.numerator * rhs.denominator,
            denominator: lhs.denominator * rhs.numerator
        )
    }

    func roundedUpToInteger() -> Int {
        if numerator <= 0 {
            return 0
        }
        return (numerator + denominator - 1) / denominator
    }

    func reduced() -> RationalQuantity {
        RationalQuantity(numerator: numerator, denominator: denominator)
    }

    func mixedFractionString(maxFractionDigits: Int = 0) -> String {
        let sign = numerator < 0 ? "-" : ""
        let absolute = RationalQuantity(numerator: abs(numerator), denominator: denominator)
        let whole = absolute.numerator / absolute.denominator
        let remainder = absolute.numerator % absolute.denominator

        if remainder == 0 {
            return "\(sign)\(whole)"
        }

        if whole == 0 {
            return "\(sign)\(remainder)/\(absolute.denominator)"
        }

        return "\(sign)\(whole) \(remainder)/\(absolute.denominator)"
    }

    func decimalString(maxFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: doubleValue)) ?? "\(doubleValue)"
    }

    private static func normalized(numerator: Int, denominator: Int) -> (numerator: Int, denominator: Int) {
        let sign = denominator < 0 ? -1 : 1
        let adjustedNumerator = numerator * sign
        let adjustedDenominator = abs(denominator)
        let divisor = gcd(abs(adjustedNumerator), adjustedDenominator)
        return (adjustedNumerator / divisor, adjustedDenominator / divisor)
    }

    private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(a, 1)
    }
}

struct ImperialQuantityFormatter {
    static func displayString(for quantity: RationalQuantity, unit: CanonicalUnit) -> String {
        switch unit.dimension {
        case .count:
            return "\(quantity.mixedFractionString()) \(unit.displayName)"
        case .mass:
            return displayMass(quantity)
        case .volume:
            return displayVolume(quantity)
        case .recipeUnit:
            return "\(quantity.mixedFractionString()) \(unit.displayName)"
        }
    }

    static func displayShoppingString(for quantity: RationalQuantity, unit: CanonicalUnit) -> String {
        switch unit.dimension {
        case .count:
            let rounded = quantity.roundedUpToInteger()
            return "\(rounded) \(unit.displayName)"
        case .mass:
            return displayMass(quantity)
        case .volume:
            return displayVolume(quantity)
        case .recipeUnit:
            return "\(quantity.mixedFractionString()) \(unit.displayName)"
        }
    }

    private static func displayMass(_ quantity: RationalQuantity) -> String {
        let ounces = quantity.doubleValue
        if ounces >= 16 {
            let pounds = Int(ounces / 16.0)
            let remainder = ounces - Double(pounds * 16)
            let remainderQuantity = RationalQuantity(numerator: Int((remainder * 100).rounded()), denominator: 100)
            if remainderQuantity.isZero {
                return "\(pounds) lb"
            }
            return "\(pounds) lb \(remainderQuantity.mixedFractionString()) oz"
        }
        return "\(quantity.mixedFractionString()) oz"
    }

    private static func displayVolume(_ quantity: RationalQuantity) -> String {
        let fluidOunces = quantity.doubleValue
        if fluidOunces >= 128 {
            let gallons = Int(fluidOunces / 128.0)
            let remainder = fluidOunces - Double(gallons * 128)
            let remainderQuantity = RationalQuantity(numerator: Int((remainder * 100).rounded()), denominator: 100)
            if remainderQuantity.isZero {
                return "\(gallons) gallon"
            }
            return "\(gallons) gallon \(remainderQuantity.mixedFractionString()) fl oz"
        }
        if fluidOunces >= 32 {
            let quarts = Int(fluidOunces / 32.0)
            let remainder = fluidOunces - Double(quarts * 32)
            let remainderQuantity = RationalQuantity(numerator: Int((remainder * 100).rounded()), denominator: 100)
            if remainderQuantity.isZero {
                return "\(quarts) quart"
            }
            return "\(quarts) quart \(remainderQuantity.mixedFractionString()) fl oz"
        }
        if fluidOunces >= 16 {
            let pints = Int(fluidOunces / 16.0)
            let remainder = fluidOunces - Double(pints * 16)
            let remainderQuantity = RationalQuantity(numerator: Int((remainder * 100).rounded()), denominator: 100)
            if remainderQuantity.isZero {
                return "\(pints) pint"
            }
            return "\(pints) pint \(remainderQuantity.mixedFractionString()) fl oz"
        }
        if fluidOunces >= 8 {
            let cups = Int(fluidOunces / 8.0)
            let remainder = fluidOunces - Double(cups * 8)
            let remainderQuantity = RationalQuantity(numerator: Int((remainder * 100).rounded()), denominator: 100)
            if remainderQuantity.isZero {
                return "\(cups) cup"
            }
            return "\(cups) cup \(remainderQuantity.mixedFractionString()) fl oz"
        }
        return "\(quantity.mixedFractionString()) fl oz"
    }
}
