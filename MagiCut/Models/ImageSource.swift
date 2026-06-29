import Foundation
import Photos

enum ImageSource: Hashable {
    case asset(PHAsset)
    case url(URL)
}
