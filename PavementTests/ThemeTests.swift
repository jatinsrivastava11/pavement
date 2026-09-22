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

/// Both looks have to pass the same readability checks.
struct ThemeTests {
    @Test("Every tier has its own color and symbol", arguments: AppTheme.allCases)
    func distinctTiers(theme: AppTheme) {
        let p = theme.palette
        #expect(Set(RarityTier.allCases.map(\.symbol)).count == RarityTier.allCases.count)
        #expect(Set(RarityTier.allCases.map { "\(p.tiers[$0]!)" }).count == RarityTier.allCases.count)
    }

    @Test("Main text is readable on the background (WCAG AA, 4.5:1)", arguments: AppTheme.allCases)
    func textContrast(theme: AppTheme) {
        let p = theme.palette
        #expect(contrast(p.textPrimary, p.background) >= 4.5, "\(theme) primary")
        #expect(contrast(p.textSecondary, p.surface) >= 4.5, "\(theme) secondary")
        #expect(contrast(p.textSecondary, p.surfaceRaised) >= 4.5, "\(theme) secondary raised")
        #expect(contrast(p.accent, p.background) >= 4.5, "\(theme) accent")
        #expect(contrast(p.danger, p.surface) >= 4.5, "\(theme) danger")
    }

    @Test("Text on buttons is readable on the accent color", arguments: AppTheme.allCases)
    func onAccentContrast(theme: AppTheme) {
        let p = theme.palette
        #expect(contrast(p.onAccent, p.accent) >= 4.5, "\(theme): \(contrast(p.onAccent, p.accent))")
    }

    @Test("Badge text is readable on every tier color (WCAG AA, 4.5:1)")
    func badgeContrast() {
        for theme in AppTheme.allCases {
            let p = theme.palette
            for tier in RarityTier.allCases {
                #expect(contrast(p.badgeText, p.tiers[tier]!) >= 4.5, "\(theme) \(tier): \(contrast(p.badgeText, p.tiers[tier]!))")
            }
        }
    }

    @Test("Tier colors stand out from the background (3:1)")
    func tierVisible() {
        for theme in AppTheme.allCases {
            let p = theme.palette
            for tier in RarityTier.allCases {
                #expect(contrast(p.tiers[tier]!, p.background) >= 3, "\(theme) \(tier): \(contrast(p.tiers[tier]!, p.background))")
            }
        }
    }

    @Test("The saved look is used, and an unknown value falls back to Asphalt")
    func selection() {
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: "appTheme")
        defer { defaults.set(original, forKey: "appTheme") }

        defaults.set("paper", forKey: "appTheme")
        #expect(AppTheme.current == .paper)
        #expect(Theme.colorScheme == .light)

        defaults.set("nonsense", forKey: "appTheme")
        #expect(AppTheme.current == .asphalt)
        #expect(Theme.colorScheme == .dark)
    }
}
