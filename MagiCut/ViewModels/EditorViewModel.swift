import SwiftUI
import Photos
import CoreImage

@Observable
@MainActor
class EditorViewModel {
    private let visionService: VisionService
    private let imageProcessingService: ImageProcessingService
    private let photoLibraryService: PhotoLibraryService
    
    let source: ImageSource
    let projectState = ProjectState()
    
    var renderedImage: CIImage?
    
    var uiImage: PlatformImage?
    var originalUIImage: PlatformImage?
    var objectContours: [CGPath] = []
    
    var isSaving: Bool = false
    var saveError: Error?
    
    init(source: ImageSource, visionService: VisionService, imageProcessingService: ImageProcessingService, photoLibraryService: PhotoLibraryService) {
        self.source = source
        self.visionService = visionService
        self.imageProcessingService = imageProcessingService
        self.photoLibraryService = photoLibraryService
    }
    
    func loadAndProcessImage() async {
        projectState.isGeneratingMask = true
        defer { projectState.isGeneratingMask = false }
        
        do {
            let ciImage: CIImage
            switch source {
            case .asset(let asset):
                guard let img = try await photoLibraryService.fetchHighQualityImage(for: asset) else { return }
                ciImage = img
            case .url(let url):
                // Handle security scoping for dragged file URLs on Mac
                _ = url.startAccessingSecurityScopedResource()
                guard let img = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
                    url.stopAccessingSecurityScopedResource()
                    return
                }
                ciImage = img
                url.stopAccessingSecurityScopedResource()
            }
            
            projectState.originalImage = ciImage
            
            if let cgImage = imageProcessingService.context.createCGImage(ciImage, from: ciImage.extent) {
                Task { @MainActor in
                    self.originalUIImage = PlatformImage(cgImage: cgImage)
                }
            }
            
            // Downsample for UI performance if needed (omitted for simplicity here, CIContext can handle it)
            projectState.displayImage = ciImage
            
            // Extract the subject
            if let session = try await visionService.generateMask(from: ciImage) {
                projectState.maskSession = session
                projectState.subjectMask = session.originalMask
            }
            
            updateRenderedImage()
            
        } catch {
            print("Failed to load or process image: \(error)")
        }
    }
    
    func updateRenderedImage() {
        guard let original = projectState.originalImage,
              let mask = projectState.subjectMask else {
            // No mask yet, just apply background edits to the whole image
            if let img = projectState.originalImage {
                renderedImage = imageProcessingService.applyAdjustments(to: img, controls: projectState.backgroundEdits)
                generatePlatformImage()
            }
            return
        }
        
        renderedImage = imageProcessingService.compositeImages(
            originalImage: original,
            subjectMask: mask,
            subjectEdits: projectState.subjectEdits,
            backgroundEdits: projectState.backgroundEdits,
            customBackgroundImage: projectState.customBackgroundImage,
            customBackgroundOffset: projectState.customBackgroundOffset,
            customBackgroundScale: projectState.customBackgroundScale
        )
        generatePlatformImage()
        
        // Generate vector contours
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            do {
                let paths = try await self.visionService.extractContours(from: mask)
                Task { @MainActor in
                    self.objectContours = paths
                }
            } catch {
                Task { @MainActor in
                    self.objectContours = []
                }
            }
        }
    }
    
    private func generatePlatformImage() {
        guard let ciImage = renderedImage else { return }
        // Scale down for UI
        let context = imageProcessingService.context
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            self.uiImage = PlatformImage(cgImage: cgImage)
        }
    }
    
    func saveToLibrary() async {
        guard let finalImage = renderedImage else { return }
        isSaving = true
        defer { isSaving = false }
        
        do {
            var originalAsset: PHAsset? = nil
            if case .asset(let asset) = source {
                originalAsset = asset
            }
            try await photoLibraryService.saveImageToLibrary(ciImage: finalImage, context: imageProcessingService.context, originalAsset: originalAsset)
        } catch {
            self.saveError = error
            print("Save failed: \(error)")
        }
    }
    
    func setTarget(_ target: EditTarget) {
        projectState.activeTarget = target
    }
    
    func revertToOriginal() {
        projectState.subjectEdits = EditControls()
        projectState.backgroundEdits = EditControls()
        projectState.customBackgroundImage = nil
        projectState.customBackgroundOffset = .zero
        projectState.customBackgroundScale = 1.0
        updateRenderedImage()
    }
    
    // MARK: - Custom Background
    
    func setCustomBackground(from data: Data) {
        guard let platformImage = PlatformImage(data: data),
              let cgImage = platformImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        projectState.customBackgroundImage = CIImage(cgImage: cgImage)
        projectState.customBackgroundOffset = .zero
        projectState.customBackgroundScale = 1.0
        
        updateRenderedImage()
    }
    
    func updateCustomBackgroundOffset(_ offset: CGSize, scale: CGFloat) {
        projectState.customBackgroundOffset = offset
        projectState.customBackgroundScale = scale
        updateRenderedImage()
    }
    
    // MARK: - Smart Brush Selection
    
    func toggleBrushMode() {
        projectState.isBrushModeActive.toggle()
        if !projectState.isBrushModeActive {
            // Revert to original auto-mask when disabling brush mode
            if let session = projectState.maskSession {
                projectState.subjectMask = session.originalMask
                updateRenderedImage()
            }
        }
    }
    
    func processBrushStrokes(points: [CGPoint]) {
        guard projectState.isBrushModeActive,
              let currentMask = projectState.subjectMask else { return }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let width = currentMask.extent.width
            let height = currentMask.extent.height
            
            // Create a grayscale context
            guard let cgContext = CGContext(
                data: nil,
                width: Int(width),
                height: Int(height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            
            // Fill background with black (cut out)
            cgContext.setFillColor(CGColor(gray: 0, alpha: 1))
            cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Create the path from normalized points
            let path = CGMutablePath()
            guard let first = points.first else { return }
            
            // Map normalized points to the mask's extent, flipping the Y axis since CoreImage origin is bottom-left
            path.move(to: CGPoint(x: first.x * width, y: (1.0 - first.y) * height))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * width, y: (1.0 - point.y) * height))
            }
            path.closeSubpath()
            
            // Draw filled path in white (keep)
            cgContext.setFillColor(CGColor(gray: 1, alpha: 1))
            cgContext.addPath(path)
            cgContext.fillPath()
            
            // Also stroke the path with a thick brush to cover the drawn outline itself
            cgContext.setStrokeColor(CGColor(gray: 1, alpha: 1))
            cgContext.setLineWidth(max(width, height) * 0.05) // 5% of max dimension
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            cgContext.addPath(path)
            cgContext.strokePath()
            
            guard let brushCGImage = cgContext.makeImage() else { return }
            let brushCIImage = CIImage(cgImage: brushCGImage)
            
            // Intersect the drawn brush mask with the current subject mask
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = currentMask
            blendFilter.backgroundImage = CIImage(color: .black).cropped(to: currentMask.extent)
            blendFilter.maskImage = brushCIImage
            
            if let newMask = blendFilter.outputImage {
                Task { @MainActor in
                    self.projectState.subjectMask = newMask
                    self.updateRenderedImage()
                }
            }
        }
    }
    
    private func updateControl(_ block: (inout EditControls) -> Void) {
        if projectState.activeTarget == .subject {
            block(&projectState.subjectEdits)
        } else {
            block(&projectState.backgroundEdits)
        }
        updateRenderedImage()
    }

    var activeExposure: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.exposure : projectState.backgroundEdits.exposure }
        set { updateControl { $0.exposure = newValue } }
    }
    
    var activeSaturation: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.saturation : projectState.backgroundEdits.saturation }
        set { updateControl { $0.saturation = newValue } }
    }
    
    var activeBrightness: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.brightness : projectState.backgroundEdits.brightness }
        set { updateControl { $0.brightness = newValue } }
    }
    
    var activeContrast: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.contrast : projectState.backgroundEdits.contrast }
        set { updateControl { $0.contrast = newValue } }
    }
    
    var activeHighlights: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.highlights : projectState.backgroundEdits.highlights }
        set { updateControl { $0.highlights = newValue } }
    }
    
    var activeShadows: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.shadows : projectState.backgroundEdits.shadows }
        set { updateControl { $0.shadows = newValue } }
    }
    
    var activeVibrance: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.vibrance : projectState.backgroundEdits.vibrance }
        set { updateControl { $0.vibrance = newValue } }
    }
    
    var activeTemperature: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.temperature : projectState.backgroundEdits.temperature }
        set { updateControl { $0.temperature = newValue } }
    }
    
    var activeTint: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.tint : projectState.backgroundEdits.tint }
        set { updateControl { $0.tint = newValue } }
    }
    
    var activeSharpness: Float {
        get { projectState.activeTarget == .subject ? projectState.subjectEdits.sharpness : projectState.backgroundEdits.sharpness }
        set { updateControl { $0.sharpness = newValue } }
    }
    
    func generateFilterPreview(for filterName: String) async -> PlatformImage? {
        guard let original = projectState.originalImage else { return nil }
        
        let activeTarget = projectState.activeTarget
        let currentSubjectEdits = projectState.subjectEdits
        let currentBackgroundEdits = projectState.backgroundEdits
        let subjectMask = projectState.subjectMask
        
        // Process on a background thread
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return nil }
            
            // Scale down the image for massive performance gain before applying complex filters
            let scale = 100.0 / max(original.extent.width, original.extent.height)
            let tinyImage = original.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            var testSubjectEdits = currentSubjectEdits
            var testBackgroundEdits = currentBackgroundEdits
            
            if activeTarget == .subject {
                testSubjectEdits.filterName = filterName
            } else {
                testBackgroundEdits.filterName = filterName
            }
            
            let customBackgroundImage = projectState.customBackgroundImage
            let customBackgroundOffset = projectState.customBackgroundOffset
            let customBackgroundScale = projectState.customBackgroundScale
            
            let finalCI: CIImage
            if let mask = subjectMask {
                let maskScaleX = tinyImage.extent.width / mask.extent.width
                let maskScaleY = tinyImage.extent.height / mask.extent.height
                let tinyMask = mask.transformed(by: CGAffineTransform(scaleX: maskScaleX, y: maskScaleY))
                
                finalCI = self.imageProcessingService.compositeImages(
                    originalImage: tinyImage,
                    subjectMask: tinyMask,
                    subjectEdits: testSubjectEdits,
                    backgroundEdits: testBackgroundEdits,
                    customBackgroundImage: customBackgroundImage,
                    customBackgroundOffset: customBackgroundOffset,
                    customBackgroundScale: customBackgroundScale
                )
            } else {
                finalCI = self.imageProcessingService.applyAdjustments(to: tinyImage, controls: testBackgroundEdits)
            }
            
            if let cgImage = self.imageProcessingService.context.createCGImage(finalCI, from: finalCI.extent) {
                return PlatformImage(cgImage: cgImage)
            }
            return nil
        }.value
    }
}
