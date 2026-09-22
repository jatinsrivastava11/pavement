import SwiftUI

/// Pavement's look: dark asphalt surfaces, one bright accent, and a color per rarity tier.
enum Theme {
    // Surfaces
    static let background = Color(red: 0.06, green: 0.06, blue: 0.07)      // asphalt
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let surfaceRaised = Color(red: 0.16, green: 0.16, blue: 0.19)
    static let hairline = Color.white.opacity(0.08)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)

    /// Destructive actions (sign out, delete). Brighter than system red so it reads on dark surfaces.
    static let danger = Color(red: 1.0, green: 0.45, blue: 0.42)

    /// Road-marking yellow. Used sparingly: primary actions and Octane.
    static let accent = Color(red: 1.0, green: 0.80, blue: 0.16)

    // Spacing and shape
    static let spacing: CGFloat = 16
    static let corner: CGFloat = 18
}

extension RarityTier {
    /// Each tier's color, from everyday grey up to legendary gold.
    var color: Color {
        switch self {
        case .common: Color(red: 0.62, green: 0.65, blue: 0.70)
        case .occasional: Color(red: 0.33, green: 0.78, blue: 0.47)
        case .niche: Color(red: 0.25, green: 0.62, blue: 1.00)
        case .rare: Color(red: 0.66, green: 0.42, blue: 1.00)
        case .exotic: Color(red: 1.00, green: 0.36, blue: 0.47)
        case .legendary: Color(red: 1.00, green: 0.76, blue: 0.20)
        }
    }

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
        Label(compact ? "" : tier.displayName.uppercased(), systemImage: tier.symbol)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.heavy))
            .tracking(0.8)
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, 5)
            .foregroundStyle(.black)   // black reads at 6:1 or better on every tier color
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
        OctaneLabel(amount: 12_300)
    }
    .padding()
    .background(Theme.background)
}
