import Foundation
import Photos
import CoreImage
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import CoreImage

/// Service responsible for interacting with the user's Photo Library
@Observable
class PhotoLibraryService {
    
    var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    
    /// Requests access to the Photo Library
    func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        Task { @MainActor in
            self.authorizationStatus = status
        }
        return status == .authorized || status == .limited
    }
    
    /// Fetches all images from the library, sorted by creation date
    func fetchAssets() -> [PHAsset] {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard currentStatus == .authorized || currentStatus == .limited else { return [] }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { (asset, _, _) in
            assets.append(asset)
        }
        return assets
    }
    
    /// Fetches a high quality CIImage from a PHAsset for editing
    func fetchHighQualityImage(for asset: PHAsset) async throws -> CIImage? {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data, let ciImage = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: ciImage)
            }
        }
    }
    
    /// Saves a CIImage to the Photo Library
    func saveImageToLibrary(ciImage: CIImage, context: CIContext) async throws {
        // Render CIImage to CGImage using DisplayP3 color space
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace) else {
            throw NSError(domain: "PhotoLibraryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image"])
        }
        let uiImage = PlatformImage(cgImage: cgImage)
        
        try await PHPhotoLibrary.shared().performChanges {
            #if canImport(UIKit)
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            #elseif canImport(AppKit)
            // On macOS, saving to Photo Library via PHAssetChangeRequest requires a URL or file path,
            // or we can just try passing the image if macOS SDK supports it.
            // Let's use the memory-based creation request if available
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: uiImage.tiffRepresentation!, options: nil)
            #endif
        }
    }
}
