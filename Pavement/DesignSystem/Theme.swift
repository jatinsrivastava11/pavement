import SwiftUI

/// The two looks you can switch between in Profile → Appearance.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    /// A: night asphalt with road-marking yellow.
    case asphalt
    /// B: daylight race programme — paper white, heavy black type, racing red.
    case paper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .asphalt: "Asphalt"
        case .paper: "Paper"
        }
    }

    var subtitle: String {
        switch self {
        case .asphalt: "Night road, yellow markings"
        case .paper: "Race programme, red and ink"
        }
    }

    /// The chosen look. Stored per device.
    static var current: AppTheme {
        get { AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .asphalt }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appTheme") }
    }

    var palette: Palette {
        switch self {
        case .asphalt:
            Palette(
                background: Color(red: 0.06, green: 0.06, blue: 0.07),
                surface: Color(red: 0.11, green: 0.11, blue: 0.13),
                surfaceRaised: Color(red: 0.16, green: 0.16, blue: 0.19),
                hairline: Color.white.opacity(0.08),
                textPrimary: .white,
                textSecondary: Color.white.opacity(0.7),
                accent: Color(red: 1.0, green: 0.80, blue: 0.16),
                onAccent: .black,
                danger: Color(red: 1.0, green: 0.45, blue: 0.42),
                badgeText: .black,
                corner: 18,
                colorScheme: .dark,
                tiers: [
                    .common: Color(red: 0.62, green: 0.65, blue: 0.70),
                    .occasional: Color(red: 0.33, green: 0.78, blue: 0.47),
                    .niche: Color(red: 0.25, green: 0.62, blue: 1.00),
                    .rare: Color(red: 0.66, green: 0.42, blue: 1.00),
                    .exotic: Color(red: 1.00, green: 0.36, blue: 0.47),
                    .legendary: Color(red: 1.00, green: 0.76, blue: 0.20),
                ]
            )
        case .paper:
            Palette(
                background: Color(red: 0.95, green: 0.94, blue: 0.91),
                surface: .white,
                surfaceRaised: Color(red: 0.89, green: 0.88, blue: 0.85),
                hairline: Color.black.opacity(0.14),
                textPrimary: Color(red: 0.07, green: 0.07, blue: 0.08),
                textSecondary: Color(red: 0.34, green: 0.34, blue: 0.36),
                accent: Color(red: 0.80, green: 0.10, blue: 0.14),
                onAccent: .white,
                danger: Color(red: 0.70, green: 0.08, blue: 0.10),
                badgeText: .white,
                corner: 8,
                colorScheme: .light,
                tiers: [
                    .common: Color(red: 0.38, green: 0.40, blue: 0.44),
                    .occasional: Color(red: 0.10, green: 0.45, blue: 0.28),
                    .niche: Color(red: 0.11, green: 0.33, blue: 0.72),
                    .rare: Color(red: 0.42, green: 0.18, blue: 0.70),
                    .exotic: Color(red: 0.76, green: 0.10, blue: 0.30),
                    .legendary: Color(red: 0.62, green: 0.42, blue: 0.02),
                ]
            )
        }
    }
}

/// Every color and shape value a screen needs, so both looks stay consistent.
struct Palette: Sendable {
    let background, surface, surfaceRaised, hairline: Color
    let textPrimary, textSecondary: Color
    /// Used for primary actions and Octane.
    let accent: Color
    /// Text drawn on top of `accent`.
    let onAccent: Color
    let danger: Color
    /// Text drawn on tier badges.
    let badgeText: Color
    let corner: CGFloat
    let colorScheme: ColorScheme
    let tiers: [RarityTier: Color]
}

/// Shorthand for the active look, so screens read `Theme.background` whichever look is on.
enum Theme {
    static var palette: Palette { AppTheme.current.palette }

    static var background: Color { palette.background }
    static var surface: Color { palette.surface }
    static var surfaceRaised: Color { palette.surfaceRaised }
    static var hairline: Color { palette.hairline }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var accent: Color { palette.accent }
    static var onAccent: Color { palette.onAccent }
    static var danger: Color { palette.danger }
    static var badgeText: Color { palette.badgeText }
    static var corner: CGFloat { palette.corner }
    static var colorScheme: ColorScheme { palette.colorScheme }

    static let spacing: CGFloat = 16
}

extension RarityTier {
    /// Each tier's color in the active look.
    var color: Color { Theme.palette.tiers[self]! }

    var symbol: String {
        switch self {
        case .common: "circle.fill"
        case .occasional: "diamond.fill"
        case .niche: "hexagon.fill"
        case .rare: "seal.fill"
        case .exotic: "flame.fill"
        case .legendary: "crown.fill"
        }
    }
}

/// A small pill showing a car's tier, e.g. "👑 LEGENDARY".
struct TierBadge: View {
    let tier: RarityTier
    var compact = false

    var body: some View {
        // Compact keeps the tier's name — it is the whole point of the badge — but sets it smaller
        // and tighter, and lets it shrink, so a long one ("OCCASIONAL") still reads in a narrow
        // card instead of being cut to "OCCASI…".
        Label(tier.displayName.uppercased(), systemImage: tier.symbol)
            .labelStyle(.titleAndIcon)
            .font(compact ? .caption2.weight(.heavy) : .caption.weight(.heavy))
            .tracking(compact ? 0.2 : 0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.vertical, 5)
            .foregroundStyle(Theme.badgeText)
            .background(tier.color, in: Capsule())
            .accessibilityLabel("\(tier.displayName) tier")
    }
}

/// Octane amount with its icon, e.g. "⛽︎ 2,000".
struct OctaneLabel: View {
    let amount: Int
    var prefix = ""
    var font: Font = .subheadline

    var body: some View {
        Label("\(prefix)\(amount.formatted())", systemImage: "fuelpump.fill")
            .font(font.weight(.bold).monospacedDigit())
            .foregroundStyle(Theme.accent)
            .accessibilityLabel("\(prefix)\(amount) Octane")
    }
}

/// A rounded card surface.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spacing)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.hairline))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

#Preview("Tiers") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(RarityTier.allCases, id: \.self) { TierBadge(tier: $0) }
        OctaneLabel(amount: 12_300, font: .title)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
}
