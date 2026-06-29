import SwiftUI
import Photos

enum EditTab {
    case adjust, filters, crop, reimagine
}

struct AdjustSidebarView: View {
    @Bindable var viewModel: EditorViewModel
    
    @State private var isLightExpanded = true
    @State private var isColorExpanded = true
    @State private var isDetailExpanded = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Target Segmented Control
                Picker("Edit Target", selection: Binding(
                    get: { viewModel.projectState.activeTarget },
                    set: { viewModel.setTarget($0) }
                )) {
                    ForEach(EditTarget.allCases) { target in
                        Text(target.rawValue).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)
                
                VStack(spacing: 24) {
                    // Light Section
                    DisclosureGroup(isExpanded: $isLightExpanded) {
                        VStack(spacing: 16) {
                            adjustmentRow(title: "Exposure", value: $viewModel.activeExposure, range: -2.0...2.0)
                            adjustmentRow(title: "Brightness", value: $viewModel.activeBrightness, range: -1.0...1.0)
                            adjustmentRow(title: "Highlights", value: $viewModel.activeHighlights, range: 0.3...1.7)
                            adjustmentRow(title: "Shadows", value: $viewModel.activeShadows, range: -1.0...1.0)
                            adjustmentRow(title: "Contrast", value: $viewModel.activeContrast, range: 0.25...4.0)
                        }
                        .padding(.top, 12)
                        .padding(.leading, 4)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sun.max")
                                Text("Light").font(.headline)
                            }
                            PreviewRibbonView(image: viewModel.uiImage, effect: "Light")
                        }
                    }
                    
                    Divider()
                    
                    // Color Section
                    DisclosureGroup(isExpanded: $isColorExpanded) {
                        VStack(spacing: 16) {
                            adjustmentRow(title: "Saturation", value: $viewModel.activeSaturation, range: 0.0...2.0)
                            adjustmentRow(title: "Vibrance", value: $viewModel.activeVibrance, range: -1.0...1.0)
                            adjustmentRow(title: "Warmth", value: $viewModel.activeTemperature, range: 2000.0...10000.0)
                            adjustmentRow(title: "Tint", value: $viewModel.activeTint, range: -100.0...100.0)
                        }
                        .padding(.top, 12)
                        .padding(.leading, 4)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "paintpalette")
                                Text("Color").font(.headline)
                            }
                            PreviewRibbonView(image: viewModel.uiImage, effect: "Color")
                        }
                    }
                    
                    Divider()
                    
                    // Detail Section
                    DisclosureGroup(isExpanded: $isDetailExpanded) {
                        VStack(spacing: 16) {
                            adjustmentRow(title: "Sharpness", value: $viewModel.activeSharpness, range: 0.0...10.0)
                        }
                        .padding(.top, 12)
                        .padding(.leading, 4)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "triangle")
                                Text("Detail").font(.headline)
                            }
                            PreviewRibbonView(image: viewModel.uiImage, effect: "B&W") // Using B&W style for Detail preview
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    @ViewBuilder
    private func adjustmentRow(title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
                .tint(.yellow)
        }
    }
}

// MARK: - Preview Ribbon View
struct PreviewRibbonView: View {
    let image: PlatformImage?
    let effect: String
    
    var body: some View {
        if let image = image {
            HStack(spacing: 1) {
                ForEach(0..<5) { i in
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .modifier(RibbonEffectModifier(effect: effect, index: i))
                }
            }
            .cornerRadius(6)
            .padding(.vertical, 4)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 36)
                .cornerRadius(6)
                .padding(.vertical, 4)
        }
    }
}

struct RibbonEffectModifier: ViewModifier {
    let effect: String
    let index: Int
    
    func body(content: Content) -> some View {
        switch effect {
        case "Light":
            // -0.4, -0.2, 0.0, 0.2, 0.4
            let brightnessValue = -0.4 + Double(index) * 0.2
            content.brightness(brightnessValue)
        case "Color":
            // 0.0 (grayscale), 0.5, 1.0 (normal), 1.5, 2.0 (vibrant)
            let satValue = Double(index) * 0.5
            content.saturation(satValue)
        case "B&W":
            // Grayscale with increasing contrast
            let contrastValue = 0.5 + Double(index) * 0.25
            content.grayscale(1.0).contrast(contrastValue)
        default:
            content
        }
    }
}
