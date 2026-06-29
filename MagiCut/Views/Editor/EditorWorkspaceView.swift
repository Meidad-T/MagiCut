import SwiftUI
import Photos

struct EditorWorkspaceView: View {
    let source: ImageSource
    @Environment(\.dependencyContainer) private var di
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: EditorViewModel?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            if let viewModel = viewModel {
                // Canvas Area
                GeometryReader { proxy in
                    ZStack {
                        if let image = viewModel.uiImage {
                            Image(platformImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = max(Constants.Editor.minZoomScale, min(Constants.Editor.maxZoomScale, value))
                                        }
                                )
                        } else {
                            ProgressView()
                                .tint(.white)
                        }
                        
                        if viewModel.projectState.isGeneratingMask {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea()
                            
                            VStack {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                                Text("Detecting Subject...")
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
                
                // Bottom Tools
                ToolPickerView(viewModel: viewModel)
            } else {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if canImport(UIKit)
            ToolbarItem(placement: .navigationBarTrailing) {
                if let viewModel = viewModel {
                    Button("Save") {
                        Task {
                            await viewModel.saveToLibrary()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.projectState.isGeneratingMask || viewModel.isSaving)
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                if let viewModel = viewModel {
                    Button("Save") {
                        Task {
                            await viewModel.saveToLibrary()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.projectState.isGeneratingMask || viewModel.isSaving)
                }
            }
            #endif
        }
        .onAppear {
            if viewModel == nil {
                let vm = EditorViewModel(source: source, visionService: di.visionService, imageProcessingService: di.imageProcessingService, photoLibraryService: di.photoLibraryService)
                self.viewModel = vm
                Task {
                    await vm.loadAndProcessImage()
                }
            }
        }
    }
}
