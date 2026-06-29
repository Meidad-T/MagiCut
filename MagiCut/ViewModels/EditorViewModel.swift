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
    var uiImage: PlatformImage? // The final display image
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
            
            // Downsample for UI performance if needed (omitted for simplicity here, CIContext can handle it)
            projectState.displayImage = ciImage
            
            // Extract the subject
            if let mask = try await visionService.generateMask(from: ciImage) {
                projectState.subjectMask = mask
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
            backgroundEdits: projectState.backgroundEdits
        )
        generatePlatformImage()
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
            try await photoLibraryService.saveImageToLibrary(ciImage: finalImage, context: imageProcessingService.context)
        } catch {
            self.saveError = error
            print("Save failed: \(error)")
        }
    }
    
    func setTarget(_ target: EditTarget) {
        projectState.activeTarget = target
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
}
