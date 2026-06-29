import SwiftUI
import Photos

@Observable
@MainActor
class GalleryViewModel {
    private let photoLibraryService: PhotoLibraryService
    
    var assets: [PHAsset] = []
    var isAuthorized: Bool = false
    
    private let imageManager = PHCachingImageManager()
    
    init(photoLibraryService: PhotoLibraryService) {
        self.photoLibraryService = photoLibraryService
        self.isAuthorized = photoLibraryService.authorizationStatus == .authorized || photoLibraryService.authorizationStatus == .limited
    }
    
    func checkPermissionsAndFetch() async {
        if !isAuthorized {
            isAuthorized = await photoLibraryService.requestAccess()
        }
        
        if isAuthorized {
            fetchAssets()
        }
    }
    
    private func fetchAssets() {
        self.assets = photoLibraryService.fetchAssets()
    }
    
    func requestThumbnail(for asset: PHAsset, targetSize: CGSize, completion: @escaping (PlatformImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        return imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }
    
    func cancelThumbnailRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
}
