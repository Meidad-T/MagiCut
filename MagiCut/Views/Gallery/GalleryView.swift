import SwiftUI
import Photos
import UniformTypeIdentifiers

struct GalleryView: View {
    @Environment(\.dependencyContainer) private var di
    @State private var viewModel: GalleryViewModel?
    
    @State private var selectedSource: ImageSource?
    
    let columnsCount: Int = {
        #if canImport(UIKit)
        return 3
        #else
        return 5
        #endif
    }()
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.isAuthorized {
                        ScrollView {
                            if let fetchResult = viewModel.fetchResult, fetchResult.count > 0 {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(0..<columnsCount, id: \.self) { colIndex in
                                        LazyVStack(spacing: 16) {
                                            let indices = stride(from: colIndex, to: fetchResult.count, by: columnsCount).map { $0 }
                                            ForEach(indices, id: \.self) { index in
                                                let asset = fetchResult.object(at: index)
                                                GalleryThumbnail(asset: asset, viewModel: viewModel)
                                                    .onTapGesture {
                                                        selectedSource = .asset(asset)
                                                    }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
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
            .navigationTitle("Recently Saved")
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {}) { Image(systemName: "minus") }
                    Button(action: {}) { Image(systemName: "plus") }
                    Spacer()
                    Button(action: {}) { Image(systemName: "info.circle") }
                    Button(action: {}) { Image(systemName: "square.and.arrow.up") }
                    Button(action: {}) { Image(systemName: "heart") }
                    Button(action: {}) { Image(systemName: "square.on.square") }
                }
            }
            .onAppear {
                if viewModel == nil {
                    let vm = GalleryViewModel(photoLibraryService: di.photoLibraryService)
                    self.viewModel = vm
                    Task {
                        await vm.checkPermissionsAndFetch()
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedSource != nil },
                set: { if !$0 { selectedSource = nil } }
            )) {
                if selectedSource != nil {
                    EditorWorkspaceView(source: $selectedSource, fetchResult: viewModel?.fetchResult)
                }
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
        let aspectRatio = asset.pixelWidth > 0 && asset.pixelHeight > 0 
            ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight) 
            : 1.0
            
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                if let image = image {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .cornerRadius(8)
            .contentShape(Rectangle())
        .onAppear {
            // Using a standard, fixed size forces PHImageManager to use its high-performance cache
            // instead of generating uniquely sized images for every slight layout variation.
            let size = CGSize(width: 300, height: 300)
            requestID = viewModel.requestThumbnail(for: asset, targetSize: size) { result in
                self.image = result
            }
        }
        .onDisappear {
            if let requestID = requestID {
                viewModel.cancelThumbnailRequest(requestID)
            }
            // Aggressively free memory when scrolled off-screen
            self.image = nil
        }
    }
}
