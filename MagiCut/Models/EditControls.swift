import Foundation
import CoreImage

/// Represents the slider values for a specific layer (subject or background)
struct EditControls: Equatable {
    var exposure: Float = 0.0     // -2.0 to 2.0
    var contrast: Float = 1.0     // 0.25 to 4.0
    var brightness: Float = 0.0   // -1.0 to 1.0
    var saturation: Float = 1.0   // 0.0 to 2.0
    
    var highlights: Float = 1.0   // 0.3 to 1.7
    var shadows: Float = 0.0      // -1.0 to 1.0
    
    var vibrance: Float = 0.0     // -1.0 to 1.0
    var temperature: Float = 6500.0 // 2000.0 to 10000.0
    var tint: Float = 0.0         // -100.0 to 100.0
    
    var sharpness: Float = 0.0    // 0.0 to 10.0
    
    var filterName: String = "Original" // Active PhotoFilter
}
