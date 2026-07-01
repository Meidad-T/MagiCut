import SwiftUI
import PhotosUI
import Photos

struct EditorWorkspaceView: View {
    @Binding var source: ImageSource?
    var fetchResult: PHFetchResult<PHAsset>? = nil
    
    @Environment(\.dependencyContainer) private var di
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: EditorViewModel?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var brushPoints: [CGPoint] = []
    @State private var trimPhase: CGFloat = 0
    @State private var isShowingOriginal: Bool = false
    
    @State private var customBackgroundItem: PhotosPickerItem? = nil
    @State private var finalCustomBackgroundOffset: CGSize = .zero
    
    @State private var isEditing: Bool = false
    @State private var editTab: EditTab = .adjust
    
    var body: some View {
        HStack(spacing: 0) {
            if let viewModel = viewModel {
                // Canvas Area
                GeometryReader { proxy in
                    ZStack {
                        if let image = viewModel.uiImage {
                            let displayImage = (isShowingOriginal && viewModel.originalUIImage != nil) ? viewModel.originalUIImage! : image
                            Image(platformImage: displayImage)
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
                                
                            if viewModel.projectState.isBrushModeActive, !viewModel.objectContours.isEmpty {
                                ZStack {
                                    // The Comet Tail (stacking opacities to create a smooth fade)
                                    ForEach(0..<15, id: \.self) { i in
                                        let tailLength = CGFloat(15 - i) * 0.02
                                        let opacity = 0.15
                                        
                                        ContourShape(contours: viewModel.objectContours)
                                            .trim(from: trimPhase - tailLength, to: trimPhase)
                                            .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 1.0, lineCap: .butt, lineJoin: .round))
                                            
                                        ContourShape(contours: viewModel.objectContours)
                                            .trim(from: trimPhase - tailLength + 1.0, to: trimPhase + 1.0)
                                            .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 1.0, lineCap: .butt, lineJoin: .round))
                                    }
                                    
                                    // The Bright Head
                                    ContourShape(contours: viewModel.objectContours)
                                        .trim(from: trimPhase - 0.02, to: trimPhase)
                                        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                                        
                                    ContourShape(contours: viewModel.objectContours)
                                        .trim(from: trimPhase - 0.02 + 1.0, to: trimPhase + 1.0)
                                        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                                }
                                .shadow(color: .white, radius: 2, x: 0, y: 0)
                                .shadow(color: .blue, radius: 5, x: 0, y: 0)
                                .aspectRatio(image.size, contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .scaleEffect(scale)
                                .offset(offset)
                                .onAppear {
                                    trimPhase = 0.0
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                            trimPhase = 1.0
                                        }
                                    }
                                }
                                .onDisappear {
                                    trimPhase = 0.0
                                }
                            }
                                
                            if viewModel.projectState.isBrushModeActive {
                                Canvas { context, size in
                                    var path = Path()
                                    guard let first = brushPoints.first else { return }
                                    path.move(to: first)
                                    for point in brushPoints.dropFirst() {
                                        path.addLine(to: point)
                                    }
                                    // Fruit Ninja Sword Effect
                                    let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
                                    let gradient = Gradient(colors: rainbowColors)
                                    let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
                                    
                                    // Outer wide glow
                                    var wideGlow = context
                                    wideGlow.addFilter(.blur(radius: 6))
                                    wideGlow.stroke(path, with: .conicGradient(gradient, center: centerPoint), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                                    
                                    // Inner tight glow
                                    var tightGlow = context
                                    tightGlow.addFilter(.blur(radius: 2))
                                    tightGlow.stroke(path, with: .conicGradient(gradient, center: centerPoint), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                    
                                    // Solid white core
                                    context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            brushPoints.append(value.location)
                                        }
                                        .onEnded { value in
                                            // Compute normalized points based on Aspect Fit size
                                            let imageAspect = image.size.width / image.size.height
                                            let containerAspect = proxy.size.width / proxy.size.height
                                            
                                            let drawRect: CGRect
                                            if imageAspect > containerAspect {
                                                let height = proxy.size.width / imageAspect
                                                drawRect = CGRect(x: 0, y: (proxy.size.height - height) / 2, width: proxy.size.width, height: height)
                                            } else {
                                                let width = proxy.size.height * imageAspect
                                                drawRect = CGRect(x: (proxy.size.width - width) / 2, y: 0, width: width, height: proxy.size.height)
                                            }
                                            
                                            let normalizedPoints = brushPoints.compactMap { point -> CGPoint? in
                                                guard drawRect.contains(point) else { return nil }
                                                return CGPoint(
                                                    x: (point.x - drawRect.minX) / drawRect.width,
                                                    y: (point.y - drawRect.minY) / drawRect.height
                                                )
                                            }
                                            
                                            viewModel.processBrushStrokes(points: normalizedPoints)
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                brushPoints.removeAll()
                                            }
                                        }
                                )
                            }
                            
                            // Left / Right Navigation Overlay
                            if !isEditing {
                                HStack {
                                    if let idx = currentIndex, idx > 0 {
                                        Button(action: goToPreviousImage) {
                                            Image(systemName: "chevron.left")
                                                .font(.largeTitle)
                                                .foregroundColor(.white)
                                                .padding()
                                                .background(Color.black.opacity(0.4).clipShape(Circle()))
                                        }
                                        .buttonStyle(.plain)
                                        .keyboardShortcut(.leftArrow, modifiers: [])
                                        .padding(.leading, 20)
                                    }
                                    
                                    Spacer()
                                    
                                    if let idx = currentIndex, let fetchResult = fetchResult, idx < fetchResult.count - 1 {
                                        Button(action: goToNextImage) {
                                            Image(systemName: "chevron.right")
                                                .font(.largeTitle)
                                                .foregroundColor(.white)
                                                .padding()
                                                .background(Color.black.opacity(0.4).clipShape(Circle()))
                                        }
                                        .buttonStyle(.plain)
                                        .keyboardShortcut(.rightArrow, modifiers: [])
                                        .padding(.trailing, 20)
                                    }
                                }
                            }
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
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if isEditing && !viewModel.projectState.isBrushModeActive {
                                    if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                                        isShowingOriginal = true
                                    } else {
                                        isShowingOriginal = false
                                        if viewModel.projectState.customBackgroundImage != nil {
                                            viewModel.beginBackgroundDrag()
                                            let newOffset = CGSize(
                                                width: finalCustomBackgroundOffset.width + value.translation.width,
                                                height: finalCustomBackgroundOffset.height + value.translation.height
                                            )
                                            viewModel.updateCustomBackgroundOffset(newOffset, scale: 1.0)
                                        }
                                    }
                                }
                            }
                            .onEnded { value in
                                isShowingOriginal = false
                                viewModel.endBackgroundDrag()
                                if viewModel.projectState.customBackgroundImage != nil, !viewModel.projectState.isBrushModeActive {
                                    finalCustomBackgroundOffset = CGSize(
                                        width: finalCustomBackgroundOffset.width + value.translation.width,
                                        height: finalCustomBackgroundOffset.height + value.translation.height
                                    )
                                }
                            }
                    )
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
                    HStack {
                        Button(action: {
                            viewModel?.undo()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!(viewModel?.canUndo ?? false))
                        .keyboardShortcut("z", modifiers: .command)
                        .help("Undo")
                        
                        Button(action: {
                            viewModel?.redo()
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .disabled(!(viewModel?.canRedo ?? false))
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                        .help("Redo")
                        
                        Button("Revert to Original") {
                            viewModel?.revertToOriginal()
                            finalCustomBackgroundOffset = .zero
                        }
                        
                        Button(action: {
                            viewModel?.toggleBrushMode()
                        }) {
                            Label("Smart Brush", systemImage: "paintbrush.pointed")
                                .foregroundColor(viewModel?.projectState.isBrushModeActive == true ? .green : .primary)
                        }
                        .help("Draw to select specific objects")
                        
                        PhotosPicker(selection: $customBackgroundItem, matching: .images) {
                            Label("Replace Background", systemImage: "photo.badge.plus")
                        }
                        .help("Choose a new background image")
                        .task(id: customBackgroundItem) {
                            if let data = try? await customBackgroundItem?.loadTransferable(type: Data.self) {
                                viewModel?.setCustomBackground(from: data)
                                finalCustomBackgroundOffset = .zero
                            }
                        }
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
                        Task {
                            await viewModel?.saveToLibrary()
                            await MainActor.run {
                                withAnimation {
                                    isEditing = false
                                }
                            }
                        }
                    }
                    .disabled(viewModel?.isSaving == true)
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
            if viewModel == nil, let currentSource = source {
                let vm = EditorViewModel(source: currentSource, visionService: di.visionService, imageProcessingService: di.imageProcessingService, photoLibraryService: di.photoLibraryService)
                self.viewModel = vm
                Task {
                    await vm.loadAndProcessImage()
                }
            }
        }
        .onChange(of: source) { newSource in
            if let newSource = newSource {
                let vm = EditorViewModel(source: newSource, visionService: di.visionService, imageProcessingService: di.imageProcessingService, photoLibraryService: di.photoLibraryService)
                self.viewModel = vm
                self.scale = 1.0
                self.offset = .zero
                self.isEditing = false
                Task {
                    await vm.loadAndProcessImage()
                }
            }
        }
    }
    
    // MARK: - Navigation Helpers
    
    private var currentIndex: Int? {
        guard let fetchResult = fetchResult,
              let source = source,
              case .asset(let asset) = source else { return nil }
        
        let index = fetchResult.index(of: asset)
        return index != NSNotFound ? index : nil
    }
    
    private func goToNextImage() {
        guard let fetchResult = fetchResult,
              let idx = currentIndex,
              idx < fetchResult.count - 1 else { return }
        let nextAsset = fetchResult.object(at: idx + 1)
        source = .asset(nextAsset)
    }
    
    private func goToPreviousImage() {
        guard let fetchResult = fetchResult,
              let idx = currentIndex,
              idx > 0 else { return }
        let prevAsset = fetchResult.object(at: idx - 1)
        source = .asset(prevAsset)
    }
}

// MARK: - Contour Shape

struct ContourShape: Shape {
    let contours: [CGPath]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Vision returns normalized paths with (0,0) at bottom-left. We flip Y for SwiftUI (top-left).
        var flipTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
        var scaleTransform = CGAffineTransform(scaleX: rect.width, y: rect.height)
        
        for contour in contours {
            if let flippedPath = contour.copy(using: &flipTransform),
               let finalPath = flippedPath.copy(using: &scaleTransform) {
                path.addPath(Path(finalPath))
            }
        }
        
        return path
    }
}
