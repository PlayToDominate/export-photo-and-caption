import Foundation
import SwiftUI

enum CaptionFontOption: String, CaseIterable, Identifiable {
    case system = "System"
    case rounded = "Rounded"
    case serif = "Serif"
    case monospaced = "Monospaced"
    case marker = "Marker"
    case script = "Script"

    var id: String { rawValue }

    var previewFont: Font {
        switch self {
        case .system:
            return .system(size: 17, weight: .regular)
        case .rounded:
            return .system(size: 17, weight: .regular, design: .rounded)
        case .serif:
            return .custom("Times New Roman", size: 17)
        case .monospaced:
            return .system(size: 17, weight: .regular, design: .monospaced)
        case .marker:
            return .custom("Marker Felt", size: 17)
        case .script:
            return .custom("Snell Roundhand", size: 18)
        }
    }
}
