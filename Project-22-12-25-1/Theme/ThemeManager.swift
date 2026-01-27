import SwiftUI

enum AppTheme: String, CaseIterable {
    case light
    case dark
    case system
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("appTheme") var selectedTheme: AppTheme = .system
    
    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

struct AppColors {
    static let success = Color(hex: "4CAF50")
    static let learning = Color(hex: "FFB300")
    static let reflection = Color(hex: "4A90E2")
    static let background = Color(hex: "FFFFFF")
    static let backgroundDark = Color(hex: "1C1C1E")
    static let cardBackground = Color(hex: "F5F5F7")
    static let cardBackgroundDark = Color(hex: "2C2C2E")
    static let textPrimary = Color(hex: "000000")
    static let textPrimaryDark = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "6E6E73")
    static let textSecondaryDark = Color(hex: "98989D")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

