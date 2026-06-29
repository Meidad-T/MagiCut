import Foundation
import Vision
import CoreImage

/// Service responsible for isolating the subject using Vision
@Observable
class VisionService {
    
    /// Generates a mask where the subject is white and background is black
    /// - Parameter ciImage: The original input image
    /// - Returns: A CIImage representing the mask, or nil if failed
    func generateMask(from ciImage: CIImage) async throws -> CIImage? {
        // VNGenerateForegroundInstanceMaskRequest is available in iOS 17+
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try handler.perform([request])
                if let result = request.results?.first {
                    let pixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                    let maskImage = CIImage(cvPixelBuffer: pixelBuffer)
                    continuation.resume(returning: maskImage)
                } else {
                    continuation.resume(returning: nil)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
