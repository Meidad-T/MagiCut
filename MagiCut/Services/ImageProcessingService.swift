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
        
        // 0. Pre-process Filter (Apple Standard & Custom Rainbows)
        if controls.filterName != "Original" {
            // Check if it's a built-in Apple filter
            if let filterMapping = getCIFilter(for: controls.filterName) {
                let filter = CIFilter(name: filterMapping)
                filter?.setValue(result, forKey: kCIInputImageKey)
                result = filter?.outputImage ?? result
            } 
            // Check if it's a custom filter
            else {
                result = applyCustomFilter(name: controls.filterName, to: result)
            }
        }
        
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
    
    // Helper to map UI string to CoreImage Filter
    private func getCIFilter(for name: String) -> String? {
        switch name {
        case "Vivid": return "CIPhotoEffectChrome"
        default: return nil
        }
    }
    
    // Complex Custom Filter Chains
    private func applyCustomFilter(name: String, to image: CIImage) -> CIImage {
        var result = image
        let extent = image.extent
        
        switch name {
        case "Old TV":
            // High contrast
            let colorFilter = CIFilter.colorControls()
            colorFilter.inputImage = result
            colorFilter.contrast = 1.3
            colorFilter.saturation = 1.5
            result = colorFilter.outputImage ?? result
            
            // Scanlines
            let lines = CIFilter.lineScreen()
            lines.inputImage = result
            lines.center = CGPoint(x: extent.midX, y: extent.midY)
            lines.angle = .pi / 2 // Horizontal scanlines
            lines.width = max(2.0, Float(extent.height) * 0.002)
            lines.sharpness = 0.7
            result = lines.outputImage ?? result
            
        case "Halftone Print":
            let halftone = CIFilter.cmykHalftone()
            halftone.inputImage = result
            halftone.center = CGPoint(x: extent.midX, y: extent.midY)
            halftone.width = max(4.0, Float(extent.width) * 0.005)
            halftone.angle = 0.5
            result = halftone.outputImage ?? result
            
        case "Hard Outline":
            let edges = CIFilter.edgeWork()
            edges.inputImage = result
            edges.radius = max(2.0, Float(extent.width) * 0.003)
            result = edges.outputImage ?? result
            
        case "Comic Book":
            let comic = CIFilter.comicEffect()
            comic.inputImage = result
            result = comic.outputImage ?? result
            
        case "Crystal Paint":
            let crystal = CIFilter.crystallize()
            crystal.inputImage = result
            crystal.radius = max(5.0, Float(min(extent.width, extent.height)) * 0.02)
            crystal.center = CGPoint(x: extent.midX, y: extent.midY)
            result = crystal.outputImage ?? result
            
        case "Pointillism":
            let point = CIFilter.pointillize()
            point.inputImage = result
            point.radius = max(3.0, Float(min(extent.width, extent.height)) * 0.015)
            point.center = CGPoint(x: extent.midX, y: extent.midY)
            result = point.outputImage ?? result
            
        case "8-Bit Retro":
            let pixel = CIFilter.pixellate()
            pixel.inputImage = result
            pixel.scale = max(4.0, Float(min(extent.width, extent.height)) * 0.015)
            pixel.center = CGPoint(x: extent.midX, y: extent.midY)
            result = pixel.outputImage ?? result
            
        case "High Contrast B&W":
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = result
            result = mono.outputImage ?? result
            
            let colorFilter = CIFilter.colorControls()
            colorFilter.inputImage = result
            colorFilter.contrast = 2.0
            colorFilter.brightness = -0.1
            result = colorFilter.outputImage ?? result
            
        case "Posterize":
            let poster = CIFilter.colorPosterize()
            poster.inputImage = result
            poster.levels = 4.0
            result = poster.outputImage ?? result
            
        default:
            break
        }
        
        return result
    }
    
    /// Generates a white outline image with a transparent background from a mask
    func generateOutlineImage(from mask: CIImage) -> PlatformImage? {
        let edgeFilter = CIFilter.morphologyGradient()
        edgeFilter.inputImage = mask
        edgeFilter.radius = 5.0
        
        guard let edgeImage = edgeFilter.outputImage else { return nil }
        
        let alphaFilter = CIFilter.maskToAlpha()
        alphaFilter.inputImage = edgeImage
        guard let finalCI = alphaFilter.outputImage else { return nil }
        
        if let cgImage = context.createCGImage(finalCI, from: mask.extent) {
            return PlatformImage(cgImage: cgImage)
        }
        return nil
    }
}
