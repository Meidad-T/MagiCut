import SwiftUI
import Photos
import UniformTypeIdentifiers

struct GalleryView: View {
    @Environment(\.dependencyContainer) private var di
    @State private var viewModel: GalleryViewModel?
    
    @State private var selectedSource: ImageSource?
    
    let columns: [GridItem] = {
        #if canImport(UIKit)
        return Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
        #else
        return Array(repeating: GridItem(.flexible(), spacing: 1), count: 5)
        #endif
    }()
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.isAuthorized {
                        ScrollView {
                            if let fetchResult = viewModel.fetchResult, fetchResult.count > 0 {
                                LazyVGrid(columns: columns, spacing: 1) {
                                    ForEach(0..<fetchResult.count, id: \.self) { index in
                                        let asset = fetchResult.object(at: index)
                                        GalleryThumbnail(asset: asset, viewModel: viewModel)
                                            .aspectRatio(1, contentMode: .fill)
                                            .clipped()
                                            .onTapGesture {
                                                selectedSource = .asset(asset)
                                            }
                                    }
                                }
                            }
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("MagiCut Needs Access")
                                .font(.title2.bold())
                            Text("Please grant access to your photos to edit subjects and backgrounds.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            Button("Grant Access") {
                                Task {
                                    await viewModel.checkPermissionsAndFetch()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Text("OR")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top)
                                
                            Text("Drag & Drop an image anywhere")
                                .font(.callout)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Photos")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .onAppear {
                if viewModel == nil {
                    let vm = GalleryViewModel(photoLibraryService: di.photoLibraryService)
                    self.viewModel = vm
                    Task {
                        await vm.checkPermissionsAndFetch()
                    }
                }
            }
            .navigationDestination(item: $selectedSource) { source in
                EditorWorkspaceView(source: source)
            }
            .dropDestination(for: URL.self) { items, location in
                if let url = items.first {
                    selectedSource = .url(url)
                    return true
                }
                return false
            }
        }
    }
}

struct GalleryThumbnail: View {
    let asset: PHAsset
    let viewModel: GalleryViewModel
    
    @State private var image: PlatformImage?
    @State private var requestID: PHImageRequestID?
    
    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = image {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .onAppear {
                // Multiplied by scale to get pixel-accurate resolution for retina
                #if canImport(UIKit)
                let scale = UIScreen.main.scale
                #else
                let scale = NSScreen.main?.backingScaleFactor ?? 1.0
                #endif
                let size = CGSize(width: proxy.size.width * scale, height: proxy.size.height * scale)
                requestID = viewModel.requestThumbnail(for: asset, targetSize: size) { result in
                    self.image = result
                }
            }
            .onDisappear {
                if let requestID = requestID {
                    viewModel.cancelThumbnailRequest(requestID)
                }
            }
        }
    }
}
