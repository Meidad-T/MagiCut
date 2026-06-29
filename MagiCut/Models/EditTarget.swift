import Foundation
import SwiftUI

/// Represents the possible targets for applying editing controls
enum EditTarget: String, CaseIterable, Identifiable {
    case subject = "Subject"
    case background = "Background"
    
    var id: String { rawValue }
}
