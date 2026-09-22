import SwiftUI
import Testing
import UIKit
@testable import Pavement

/// Contrast ratio between two colors (WCAG 2.1), used to keep text readable.
private func contrast(_ a: Color, _ b: Color) -> Double {
    func luminance(_ c: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &bl, alpha: &al)
        func ch(_ v: CGFloat) -> Double { let v = Double(v); return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(bl)
    }
    let (l1, l2) = (luminance(a), luminance(b))
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
}

struct ThemeTests {
    @Test("Every tier has its own color and symbol")
    func distinctTiers() {
        #expect(Set(RarityTier.allCases.map(\.symbol)).count == RarityTier.allCases.count)
        #expect(Set(RarityTier.allCases.map { "\($0.color)" }).count == RarityTier.allCases.count)
    }

    @Test("Main text is readable on the background (WCAG AA, 4.5:1)")
    func textContrast() {
        #expect(contrast(Theme.textPrimary, Theme.background) >= 4.5)
        #expect(contrast(Theme.textSecondary, Theme.surface) >= 4.5)
        #expect(contrast(Theme.accent, Theme.background) >= 4.5)
    }

    @Test("Badge text (black) is readable on every tier color (WCAG AA, 4.5:1)", arguments: RarityTier.allCases)
    func badgeContrast(tier: RarityTier) {
        #expect(contrast(.black, tier.color) >= 4.5, "\(tier): \(contrast(.black, tier.color))")
    }

    @Test("Tier colors stand out from the background (3:1)", arguments: RarityTier.allCases)
    func tierVisible(tier: RarityTier) {
        #expect(contrast(tier.color, Theme.background) >= 3, "\(tier)")
    }
}
