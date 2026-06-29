import SwiftUI
import Photos

struct EditorWorkspaceView: View {
    let source: ImageSource
    @Environment(\.dependencyContainer) private var di
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: EditorViewModel?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    @State private var isEditing: Bool = false
    @State private var editTab: EditTab = .adjust
    
    var body: some View {
        HStack(spacing: 0) {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                
                // Right Sidebar (Edit Mode)
                if isEditing {
                    Divider()
                        .ignoresSafeArea()
                    
                    VStack {
                        if editTab == .adjust {
                            AdjustSidebarView(viewModel: viewModel)
                        } else if editTab == .filters {
                            FiltersSidebarView(viewModel: viewModel)
                        } else if editTab == .reimagine {
                            ReimagineSidebarView(viewModel: viewModel)
                        } else {
                            Text("Crop - Coming Soon")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 320)
                    .background(Color(NSColor.windowBackgroundColor))
                    .transition(.move(edge: .trailing))
                }
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
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .navigation) {
                    Button("Revert to Original") {
                        viewModel?.revertToOriginal()
                    }
                }
                
                ToolbarItemGroup(placement: .principal) {
                    Picker("", selection: $editTab) {
                        Text("Adjust").tag(EditTab.adjust)
                        Text("Filters").tag(EditTab.filters)
                        Text("Crop").tag(EditTab.crop)
                        Text("Re-imagine").tag(EditTab.reimagine)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 350)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        withAnimation {
                            isEditing = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundColor(.black)
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {}) { Image(systemName: "info.circle") }
                    Button(action: {}) { Image(systemName: "square.and.arrow.up") }
                    Button(action: {}) { Image(systemName: "heart") }
                    Button(action: {}) { Image(systemName: "flip.horizontal") }
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isEditing = true
                        }
                    }) { 
                        Image(systemName: "wand.and.stars") 
                    }
                    .help("Edit (Magic Brush)")
                }
            }
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
