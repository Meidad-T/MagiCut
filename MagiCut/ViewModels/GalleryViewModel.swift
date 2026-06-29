import SwiftUI
import Photos

@Observable
@MainActor
class GalleryViewModel: NSObject, PHPhotoLibraryChangeObserver {
    private let photoLibraryService: PhotoLibraryService
    
    var fetchResult: PHFetchResult<PHAsset>?
    var isAuthorized: Bool = false
    
    private let imageManager = PHCachingImageManager()
    
    init(photoLibraryService: PhotoLibraryService) {
        self.photoLibraryService = photoLibraryService
        self.isAuthorized = photoLibraryService.authorizationStatus == .authorized || photoLibraryService.authorizationStatus == .limited
        super.init()
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
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
        self.fetchResult = photoLibraryService.fetchAssets()
    }
    
    func refresh() async {
        try? await Task.sleep(nanoseconds: 300_000_000) // Small delay for UI effect
        fetchAssets()
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
    
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let currentFetchResult = self.fetchResult else { return }
            if let changes = changeInstance.changeDetails(for: currentFetchResult) {
                self.fetchResult = changes.fetchResultAfterChanges
            }
        }
    }
}
