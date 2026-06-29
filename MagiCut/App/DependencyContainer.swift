import Foundation
import SwiftUI

/// Environment key for dependency injection
struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = DependencyContainer()
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

/// The main Dependency Container that holds and provides Services to ViewModels
@Observable
class DependencyContainer {
    let visionService: VisionService
    let imageProcessingService: ImageProcessingService
    let photoLibraryService: PhotoLibraryService
    
    init() {
        self.visionService = VisionService()
        self.imageProcessingService = ImageProcessingService()
        self.photoLibraryService = PhotoLibraryService()
    }
}
