import Foundation
import SwiftUI

/// Application constants for UI and default values
struct Constants {
    struct UI {
        static let defaultPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let bottomToolbarHeight: CGFloat = 120
    }
    
    struct Editor {
        static let maxZoomScale: CGFloat = 5.0
        static let minZoomScale: CGFloat = 1.0
    }
}
