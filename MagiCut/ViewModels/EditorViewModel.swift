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
    
    var hasUnsavedChanges: Bool = false
    
    var isSaving: Bool = false
    var saveError: Error?
    
    // MARK: - Undo/Redo State
    private var undoStack: [ProjectStateSnapshot] = []
    private var redoStack: [ProjectStateSnapshot] = []
    private let maxHistory = 15
    private var isDraggingBackground = false
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
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
            projectState.bakedImage = ciImage
            
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
        guard let base = projectState.bakedImage ?? projectState.originalImage else { return }
        let baseWithGlobalEdits = imageProcessingService.applyAdjustments(to: base, controls: projectState.wholeImageEdits)
        
        guard let mask = projectState.subjectMask else {
            // No mask yet, just apply background edits to the whole image
            renderedImage = imageProcessingService.applyAdjustments(to: baseWithGlobalEdits, controls: projectState.backgroundEdits)
            generatePlatformImage()
            return
        }
        
        renderedImage = imageProcessingService.compositeImages(
            originalImage: baseWithGlobalEdits,
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
        guard hasUnsavedChanges else { return }
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
    
    // MARK: - Undo / Redo
    
    func snapshotState() {
        let snapshot = ProjectStateSnapshot(
            bakedImage: projectState.bakedImage,
            subjectMask: projectState.subjectMask,
            wholeImageEdits: projectState.wholeImageEdits,
            subjectEdits: projectState.subjectEdits,
            backgroundEdits: projectState.backgroundEdits,
            customBackgroundImage: projectState.customBackgroundImage,
            customBackgroundOffset: projectState.customBackgroundOffset,
            customBackgroundScale: projectState.customBackgroundScale,
            activeTarget: projectState.activeTarget,
            isBrushModeActive: projectState.isBrushModeActive
        )
        undoStack.append(snapshot)
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }
    
    private func applySnapshot(_ snapshot: ProjectStateSnapshot) {
        projectState.bakedImage = snapshot.bakedImage
        projectState.subjectMask = snapshot.subjectMask
        projectState.wholeImageEdits = snapshot.wholeImageEdits
        projectState.subjectEdits = snapshot.subjectEdits
        projectState.backgroundEdits = snapshot.backgroundEdits
        projectState.customBackgroundImage = snapshot.customBackgroundImage
        projectState.customBackgroundOffset = snapshot.customBackgroundOffset
        projectState.customBackgroundScale = snapshot.customBackgroundScale
        projectState.activeTarget = snapshot.activeTarget
        projectState.isBrushModeActive = snapshot.isBrushModeActive
        
        hasUnsavedChanges = true
        updateRenderedImage()
    }
    
    func undo() {
        guard let last = undoStack.popLast() else { return }
        
        let current = ProjectStateSnapshot(
            bakedImage: projectState.bakedImage,
            subjectMask: projectState.subjectMask,
            wholeImageEdits: projectState.wholeImageEdits,
            subjectEdits: projectState.subjectEdits,
            backgroundEdits: projectState.backgroundEdits,
            customBackgroundImage: projectState.customBackgroundImage,
            customBackgroundOffset: projectState.customBackgroundOffset,
            customBackgroundScale: projectState.customBackgroundScale,
            activeTarget: projectState.activeTarget,
            isBrushModeActive: projectState.isBrushModeActive
        )
        redoStack.append(current)
        applySnapshot(last)
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        
        let current = ProjectStateSnapshot(
            bakedImage: projectState.bakedImage,
            subjectMask: projectState.subjectMask,
            wholeImageEdits: projectState.wholeImageEdits,
            subjectEdits: projectState.subjectEdits,
            backgroundEdits: projectState.backgroundEdits,
            customBackgroundImage: projectState.customBackgroundImage,
            customBackgroundOffset: projectState.customBackgroundOffset,
            customBackgroundScale: projectState.customBackgroundScale,
            activeTarget: projectState.activeTarget,
            isBrushModeActive: projectState.isBrushModeActive
        )
        undoStack.append(current)
        applySnapshot(next)
    }
    
    func revertToOriginal() {
        snapshotState()
        projectState.wholeImageEdits = EditControls()
        projectState.subjectEdits = EditControls()
        projectState.backgroundEdits = EditControls()
        projectState.customBackgroundImage = nil
        projectState.customBackgroundOffset = .zero
        projectState.customBackgroundScale = 1.0
        projectState.bakedImage = projectState.originalImage
        if let session = projectState.maskSession {
            projectState.subjectMask = session.originalMask
        }
        updateRenderedImage()
    }
    
    // MARK: - Custom Background
    
    func beginBackgroundDrag() {
        if !isDraggingBackground {
            snapshotState()
            isDraggingBackground = true
        }
    }
    
    func endBackgroundDrag() {
        isDraggingBackground = false
    }
    
    func setCustomBackground(from data: Data) {
        guard let platformImage = PlatformImage(data: data),
              let cgImage = platformImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        snapshotState()
        hasUnsavedChanges = true
        projectState.customBackgroundImage = CIImage(cgImage: cgImage)
        projectState.customBackgroundOffset = .zero
        projectState.customBackgroundScale = 1.0
        
        updateRenderedImage()
    }
    
    func updateCustomBackgroundOffset(_ offset: CGSize, scale: CGFloat) {
        hasUnsavedChanges = true
        projectState.customBackgroundOffset = offset
        projectState.customBackgroundScale = scale
        updateRenderedImage()
    }
    
    // MARK: - Smart Brush Selection
    
    func bakeEdits() {
        if let rendered = renderedImage {
            hasUnsavedChanges = true
            projectState.bakedImage = rendered
            
            projectState.wholeImageEdits = EditControls()
            projectState.subjectEdits = EditControls()
            projectState.backgroundEdits = EditControls()
            projectState.customBackgroundImage = nil
            projectState.customBackgroundOffset = .zero
            projectState.customBackgroundScale = 1.0
        }
    }
    
    func toggleBrushMode() {
        snapshotState()
        bakeEdits()
        
        projectState.isBrushModeActive.toggle()
        
        if projectState.isBrushModeActive {
            projectState.activeTarget = .subject
        } else {
            // Revert to original auto-mask when disabling brush mode
            if let session = projectState.maskSession {
                projectState.subjectMask = session.originalMask
            }
        }
        
        updateRenderedImage()
    }
    
    func processBrushStrokes(points: [CGPoint]) {
        guard projectState.isBrushModeActive,
              let currentMask = projectState.subjectMask else { return }
              
        // Bake any pending slider edits BEFORE creating the new smaller selection!
        snapshotState()
        bakeEdits()
        
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
            cgContext.setLineWidth(max(width, height) * 0.015) // Approx 1/3 of previous 0.05
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            cgContext.addPath(path)
            cgContext.strokePath()
            
            guard let brushCGImage = cgContext.makeImage() else { return }
            let brushCIImage = CIImage(cgImage: brushCGImage)
            
            // 1. Blur the drawn brush mask so it has soft edges that can snap to image contours
            let blurRadius = max(width, height) * 0.01 // Reduced blur to match thinner line
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = brushCIImage
            blurFilter.radius = Float(blurRadius)
            let blurredBrush = blurFilter.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: width, height: height)) ?? brushCIImage
            
            // 2. Use Guided Filter to snap the soft edges to the high-contrast edges in the original image
            var snappedMask = blurredBrush
            if let originalImage = self.projectState.originalImage,
               let guidedFilter = CIFilter(name: "CIGuidedFilter") {
                
                // Ensure guide image perfectly matches the mask's extent and origin
                let scaleX = width / originalImage.extent.width
                let scaleY = height / originalImage.extent.height
                let guideTransform = CGAffineTransform(translationX: -originalImage.extent.origin.x, y: -originalImage.extent.origin.y).scaledBy(x: scaleX, y: scaleY)
                let safeGuide = originalImage.transformed(by: guideTransform)
                
                guidedFilter.setValue(blurredBrush, forKey: kCIInputImageKey)
                guidedFilter.setValue(safeGuide, forKey: "inputGuideImage")
                guidedFilter.setValue(NSNumber(value: Float(blurRadius * 2.0)), forKey: "inputRadius")
                guidedFilter.setValue(NSNumber(value: 0.001), forKey: "inputEpsilon")
                
                if let output = guidedFilter.outputImage {
                    // 3. Threshold the snapped mask to make it hard again
                    let thresholdFilter = CIFilter.colorControls()
                    thresholdFilter.inputImage = output
                    thresholdFilter.contrast = 50.0 // Push to hard edges
                    thresholdFilter.brightness = 0.0
                    
                    // CLAMP output to [0,1] to prevent math artifacts in blending
                    let clampFilter = CIFilter.colorClamp()
                    clampFilter.inputImage = thresholdFilter.outputImage
                    clampFilter.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
                    clampFilter.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
                    
                    snappedMask = clampFilter.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: width, height: height)) ?? output
                }
            }
            
            // Re-align snapped mask back to currentMask's original extent if it was shifted
            let finalMask = snappedMask.transformed(by: CGAffineTransform(translationX: currentMask.extent.origin.x, y: currentMask.extent.origin.y))
            
            // Intersect the smart brush mask with the current subject mask
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = currentMask
            blendFilter.backgroundImage = CIImage(color: .black).cropped(to: currentMask.extent)
            blendFilter.maskImage = finalMask
            
            if let newMask = blendFilter.outputImage {
                let extent = newMask.extent
                let maxFilter = CIFilter(name: "CIAreaMaximum")!
                maxFilter.setValue(newMask, forKey: kCIInputImageKey)
                maxFilter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
                
                var isEmpty = false
                if let output = maxFilter.outputImage {
                    var bitmap = [UInt8](repeating: 0, count: 4)
                    self.imageProcessingService.context.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
                    
                    // The red channel represents the mask intensity. < 5 means it's effectively blank.
                    if bitmap[0] < 5 {
                        isEmpty = true
                    }
                }
                
                if isEmpty {
                    Task { @MainActor in
                        self.undo()
                    }
                    return
                }
                
                Task { @MainActor in
                    self.projectState.subjectMask = newMask
                    self.updateRenderedImage()
                }
            }
        }
    }
    
    private func updateControl(_ block: (inout EditControls) -> Void) {
        hasUnsavedChanges = true
        switch projectState.activeTarget {
        case .wholeImage:
            block(&projectState.wholeImageEdits)
        case .subject:
            block(&projectState.subjectEdits)
        case .background:
            block(&projectState.backgroundEdits)
        }
        updateRenderedImage()
    }
    
    private var activeEdits: EditControls {
        switch projectState.activeTarget {
        case .wholeImage: return projectState.wholeImageEdits
        case .subject: return projectState.subjectEdits
        case .background: return projectState.backgroundEdits
        }
    }

    var activeExposure: Float {
        get { activeEdits.exposure }
        set { updateControl { $0.exposure = newValue } }
    }
    
    var activeSaturation: Float {
        get { activeEdits.saturation }
        set { updateControl { $0.saturation = newValue } }
    }
    
    var activeBrightness: Float {
        get { activeEdits.brightness }
        set { updateControl { $0.brightness = newValue } }
    }
    
    var activeContrast: Float {
        get { activeEdits.contrast }
        set { updateControl { $0.contrast = newValue } }
    }
    
    var activeHighlights: Float {
        get { activeEdits.highlights }
        set { updateControl { $0.highlights = newValue } }
    }
    
    var activeShadows: Float {
        get { activeEdits.shadows }
        set { updateControl { $0.shadows = newValue } }
    }
    
    var activeVibrance: Float {
        get { activeEdits.vibrance }
        set { updateControl { $0.vibrance = newValue } }
    }
    
    var activeTemperature: Float {
        get { activeEdits.temperature }
        set { updateControl { $0.temperature = newValue } }
    }
    
    var activeTint: Float {
        get { activeEdits.tint }
        set { updateControl { $0.tint = newValue } }
    }
    
    var activeSharpness: Float {
        get { activeEdits.sharpness }
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
            
            var testWholeImageEdits = self.projectState.wholeImageEdits
            var testSubjectEdits = currentSubjectEdits
            var testBackgroundEdits = currentBackgroundEdits
            
            if activeTarget == .wholeImage {
                testWholeImageEdits.filterName = filterName
            } else if activeTarget == .subject {
                testSubjectEdits.filterName = filterName
            } else {
                testBackgroundEdits.filterName = filterName
            }
            
            let customBackgroundImage = self.projectState.customBackgroundImage
            let customBackgroundOffset = self.projectState.customBackgroundOffset
            let customBackgroundScale = self.projectState.customBackgroundScale
            
            let tinyImageWithGlobal = self.imageProcessingService.applyAdjustments(to: tinyImage, controls: testWholeImageEdits)
            
            let finalCI: CIImage
            if let mask = subjectMask {
                let maskScaleX = tinyImage.extent.width / mask.extent.width
                let maskScaleY = tinyImage.extent.height / mask.extent.height
                let tinyMask = mask.transformed(by: CGAffineTransform(scaleX: maskScaleX, y: maskScaleY))
                
                finalCI = self.imageProcessingService.compositeImages(
                    originalImage: tinyImageWithGlobal,
                    subjectMask: tinyMask,
                    subjectEdits: testSubjectEdits,
                    backgroundEdits: testBackgroundEdits,
                    customBackgroundImage: customBackgroundImage,
                    customBackgroundOffset: customBackgroundOffset,
                    customBackgroundScale: customBackgroundScale
                )
            } else {
                finalCI = self.imageProcessingService.applyAdjustments(to: tinyImageWithGlobal, controls: testBackgroundEdits)
            }
            
            if let cgImage = self.imageProcessingService.context.createCGImage(finalCI, from: finalCI.extent) {
                return PlatformImage(cgImage: cgImage)
            }
            return nil
        }.value
    }
}
