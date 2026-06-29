import SwiftUI

@main
struct MagicMaskApp: App {
    @State private var dependencyContainer = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            GalleryView()
                .environment(\.dependencyContainer, dependencyContainer)
        }
    }
}
