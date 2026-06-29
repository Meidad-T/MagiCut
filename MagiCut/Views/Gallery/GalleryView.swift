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
                        CustomRefreshableScrollView(onRefresh: {
                            await viewModel.refresh()
                        }) {
                            if let fetchResult = viewModel.fetchResult, fetchResult.count > 0 {
                                LazyVGrid(columns: columns, spacing: 1) {
                                    ForEach(0..<fetchResult.count, id: \.self) { index in
                                        let asset = fetchResult.object(at: index)
                                        GalleryThumbnail(asset: asset, viewModel: viewModel)
                                            .onTapGesture {
                                                selectedSource = .asset(asset)
                                            }
                                    }
                                }
                            }
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
                } else {
                    Task {
                        await viewModel?.refresh()
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
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
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
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .onAppear {
                        // Multiplied by scale to get pixel-accurate resolution for retina
                        #if canImport(UIKit)
                        let scale = UIScreen.main.scale
                        #else
                        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
                        #endif
                        
                        let safeWidth = max(100, proxy.size.width)
                        let safeHeight = max(100, proxy.size.height)
                        let size = CGSize(width: safeWidth * scale, height: safeHeight * scale)
                        
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
            )
            .clipped()
    }
}

// MARK: - Custom macOS Pull-to-Refresh

struct CustomRefreshableScrollView<Content: View>: View {
    var onRefresh: () async -> Void
    @ViewBuilder var content: () -> Content
    
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isRefreshing {
                    ProgressView()
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                }
                
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
                .frame(height: 0)
                
                content()
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            // When user over-scrolls past 60 points at the top
            if value > 60 && !isRefreshing {
                withAnimation(.spring()) {
                    isRefreshing = true
                }
                Task {
                    await onRefresh()
                    withAnimation(.spring()) {
                        isRefreshing = false
                    }
                }
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
