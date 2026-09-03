import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.12, green: 0.38, blue: 0.48)
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.15)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let secondary = Color(uiColor: .secondaryLabel)

    static func titleFont(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
