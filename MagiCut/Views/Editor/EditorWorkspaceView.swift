import SwiftUI
import Photos

struct EditorWorkspaceView: View {
    let source: ImageSource
    @Environment(\.dependencyContainer) private var di
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: EditorViewModel?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var brushPoints: [CGPoint] = []
    @State private var trimPhase: CGFloat = 0
    
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
                                
                            if viewModel.projectState.isBrushModeActive, !viewModel.objectContours.isEmpty {
                                ZStack {
                                    ContourShape(contours: viewModel.objectContours)
                                        .trim(from: trimPhase, to: trimPhase + 0.05)
                                        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                                        
                                    ContourShape(contours: viewModel.objectContours)
                                        .trim(from: trimPhase - 1.0, to: trimPhase - 0.95)
                                        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                                }
                                .shadow(color: .white, radius: 2, x: 0, y: 0)
                                .shadow(color: .blue, radius: 4, x: 0, y: 0)
                                .aspectRatio(image.size, contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .scaleEffect(scale)
                                .offset(offset)
                                .onAppear {
                                    trimPhase = 0.0
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
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
                                    context.stroke(path, with: .color(.green.opacity(0.8)), style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
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
                    HStack {
                        Button("Revert to Original") {
                            viewModel?.revertToOriginal()
                        }
                        
                        Button(action: {
                            viewModel?.toggleBrushMode()
                        }) {
                            Label("Smart Brush", systemImage: "paintbrush.pointed")
                                .foregroundColor(viewModel?.projectState.isBrushModeActive == true ? .green : .primary)
                        }
                        .help("Draw to select specific objects")
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
