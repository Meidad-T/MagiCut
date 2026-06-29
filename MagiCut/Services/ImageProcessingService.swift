import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Service responsible for rendering filters and compositing images using Metal-backed CoreImage
@Observable
class ImageProcessingService {
    // Shared Metal-backed context for performance
    let context = CIContext(options: [
        .cacheIntermediates: false,
        .useSoftwareRenderer: false,
        .name: "com.magicmask.metal-context"
    ])
    
    /// Applies color controls (saturation, brightness, contrast) to an image
    func applyAdjustments(to image: CIImage, controls: EditControls) -> CIImage {
        var result = image
        
        // 1. Exposure
        if controls.exposure != 0.0 {
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = result
            exposureFilter.ev = controls.exposure
            result = exposureFilter.outputImage ?? result
        }
        
        // 2. Color Controls (Saturation, Brightness, Contrast)
        if controls.saturation != 1.0 || controls.brightness != 0.0 || controls.contrast != 1.0 {
            let colorFilter = CIFilter.colorControls()
            colorFilter.inputImage = result
            colorFilter.saturation = controls.saturation
            colorFilter.brightness = controls.brightness
            colorFilter.contrast = controls.contrast
            result = colorFilter.outputImage ?? result
        }
        
        // 3. Highlights & Shadows
        if controls.highlights != 1.0 || controls.shadows != 0.0 {
            let hsFilter = CIFilter.highlightShadowAdjust()
            hsFilter.inputImage = result
            hsFilter.highlightAmount = controls.highlights
            hsFilter.shadowAmount = controls.shadows
            result = hsFilter.outputImage ?? result
        }
        
        // 4. Vibrance
        if controls.vibrance != 0.0 {
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = result
            vibranceFilter.amount = controls.vibrance
            result = vibranceFilter.outputImage ?? result
        }
        
        // 5. Temperature & Tint
        if controls.temperature != 6500.0 || controls.tint != 0.0 {
            let tempTintFilter = CIFilter.temperatureAndTint()
            tempTintFilter.inputImage = result
            tempTintFilter.neutral = CIVector(x: 6500.0, y: 0.0)
            tempTintFilter.targetNeutral = CIVector(x: CGFloat(controls.temperature), y: CGFloat(controls.tint))
            result = tempTintFilter.outputImage ?? result
        }
        
        // 6. Sharpening
        if controls.sharpness > 0 {
            let sharpenFilter = CIFilter.sharpenLuminance()
            sharpenFilter.inputImage = result
            sharpenFilter.sharpness = controls.sharpness
            result = sharpenFilter.outputImage ?? result
        }
        
        return result
    }
    
    /// Composites the edited subject and edited background using the vision mask
    func compositeImages(originalImage: CIImage, subjectMask: CIImage, subjectEdits: EditControls, backgroundEdits: EditControls) -> CIImage {
        // 1. Apply edits to the background layer
        let editedBackground = applyAdjustments(to: originalImage, controls: backgroundEdits)
        
        // 2. Apply edits to the subject layer (which is technically just the original image, edited, then masked)
        let editedSubject = applyAdjustments(to: originalImage, controls: subjectEdits)
        
        // 3. Scale the mask to match the original image size, since Vision might output a smaller mask
        let scaleX = originalImage.extent.width / subjectMask.extent.width
        let scaleY = originalImage.extent.height / subjectMask.extent.height
        let scaledMask = subjectMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 4. Composite using CIBlendWithMask
        // foreground: editedSubject
        // background: editedBackground
        // mask: scaledMask
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = editedSubject
        blendFilter.backgroundImage = editedBackground
        blendFilter.maskImage = scaledMask
        
        return blendFilter.outputImage ?? originalImage
    }
}
