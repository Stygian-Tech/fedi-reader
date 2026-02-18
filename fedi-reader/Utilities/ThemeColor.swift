import SwiftUI

enum ThemeColor: String, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .gray: return .gray
        }
    }
    
    var requiresContrastStrokeInPreview: Bool {
        switch self {
        case .yellow, .mint, .cyan:
            return true
        default:
            return false
        }
    }
    
    static func resolved(from rawValue: String) -> ThemeColor {
        ThemeColor(rawValue: rawValue) ?? .blue
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

