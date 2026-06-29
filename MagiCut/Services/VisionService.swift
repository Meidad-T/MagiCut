import Foundation
import Vision
import CoreImage

/// Service responsible for isolating the subject using Vision
@Observable
class VisionService {
    
    /// Generates the initial mask and returns the session
    func generateMask(from ciImage: CIImage) async throws -> SubjectMaskSession? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try handler.perform([request])
                if let result = request.results?.first {
                    let pixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                    let maskImage = CIImage(cvPixelBuffer: pixelBuffer)
                    let session = SubjectMaskSession(observation: result, requestHandler: handler, originalMask: maskImage)
                    continuation.resume(returning: session)
                } else {
                    continuation.resume(returning: nil)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Reads the CVPixelBuffer to find the Instance IDs at the given normalized (0-1) coordinates
    func getInstances(at normalizedPoints: [CGPoint], in session: SubjectMaskSession) -> IndexSet {
        let instanceMask = session.observation.instanceMask
        
        CVPixelBufferLockBaseAddress(instanceMask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(instanceMask, .readOnly) }
        
        let width = CVPixelBufferGetWidth(instanceMask)
        let height = CVPixelBufferGetHeight(instanceMask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(instanceMask)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(instanceMask) else { return IndexSet() }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var selectedInstances = IndexSet()
        
        for point in normalizedPoints {
            // Normalized points from SwiftUI typically have 0,0 at top-left.
            // VNInstanceMask CVPixelBuffer also has 0,0 at top-left.
            let x = Int(point.x * CGFloat(width))
            let y = Int(point.y * CGFloat(height))
            
            let clampedX = min(max(x, 0), width - 1)
            let clampedY = min(max(y, 0), height - 1)
            
            let byteIndex = clampedY * bytesPerRow + clampedX
            let instanceId = buffer[byteIndex]
            
            if instanceId > 0 { // 0 is background
                selectedInstances.insert(Int(instanceId))
            }
        }
        
        return selectedInstances
    }
    
    /// Generates a new CIImage mask isolating only the specific instances
    func generateMask(for instances: IndexSet, in session: SubjectMaskSession) throws -> CIImage? {
        guard !instances.isEmpty else { return nil }
        let pixelBuffer = try session.observation.generateScaledMaskForImage(forInstances: instances, from: session.requestHandler)
        return CIImage(cvPixelBuffer: pixelBuffer)
    }
}
