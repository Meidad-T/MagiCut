import Foundation
import Vision
import CoreImage

/// Holds the active Vision masking session so we can generate new sub-masks from a single pass
struct SubjectMaskSession {
    let observation: VNInstanceMaskObservation
    let requestHandler: VNImageRequestHandler
    let originalMask: CIImage // The default full mask
}
