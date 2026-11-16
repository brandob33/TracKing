import SwiftUI
import UIKit

/// The app's colors, in one place. Right now this is a UC Irvine theme: UCI blue and gold.
/// To change the look of the whole app (and the lock screen), change the values here.
///
/// Colors with a light and a dark value switch with the phone's appearance, and are picked
/// so text stays readable in both.
nonisolated enum Theme {
    // MARK: Brand

    /// UCI blue, for links, icons, and anything tappable. Lighter in dark mode so it stays readable.
    static let blue = Color(light: 0x0064A4, dark: 0x5CB0F2)
    /// UCI gold, for fills and outlines. Put `navy` text on it, never white.
    static let gold = Color(hex: 0xFFD200)
    /// UCI gold that's readable as text: darker on a white background, full gold on a dark one.
    static let goldText = Color(light: 0x8A6500, dark: 0xFFD200)
    /// UCI dark blue, for text on gold.
    static let navy = Color(hex: 0x1B3D6D)
    /// The darkest blue, for the lock-screen background.
    static let midnight = Color(hex: 0x002244)

    // MARK: Timing states

    /// The GO button. White text goes on top.
    static let goFill = Color(light: 0x1A8748, dark: 0x1F9A53)
    /// Green text and icons: ready, done, on target.
    static let go = Color(light: 0x1A8748, dark: 0x3DCB7A)
    /// The Finish button. White text goes on top.
    static let finishFill = Color(light: 0x0064A4, dark: 0x1479C2)
    /// Rest countdowns and rest buttons.
    static let rest = Color(light: 0xB85A00, dark: 0xF78D2D)
    /// Rest on the lock screen, which is always dark.
    static let restOnDark = Color(hex: 0xF78D2D)
    /// The outline and progress bar when rest is over and a group is due on the line.
    static let call = Color(light: 0xE0A300, dark: 0xFFD200)
}

nonisolated extension Color {
    /// A color from a hex value like `0x0064A4`.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A color that uses one hex value in light mode and another in dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

nonisolated extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
