import SwiftUI

enum EditingTool: String, CaseIterable, Identifiable {
    case exposure = "Exposure"
    case brightness = "Brightness"
    case contrast = "Contrast"
    case highlights = "Highlights"
    case shadows = "Shadows"
    case saturation = "Saturation"
    case vibrance = "Vibrance"
    case warmth = "Warmth"
    case tint = "Tint"
    case sharpness = "Sharpness"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .exposure: return "plusminus.circle"
        case .brightness: return "sun.max"
        case .contrast: return "circle.lefthalf.filled"
        case .highlights: return "sun.min"
        case .shadows: return "circle.fill"
        case .saturation: return "drop.fill"
        case .vibrance: return "sparkles"
        case .warmth: return "thermometer.sun"
        case .tint: return "eyedropper"
        case .sharpness: return "triangle"
        }
    }
}

struct ToolPickerView: View {
    @Bindable var viewModel: EditorViewModel
    @State private var selectedTool: EditingTool = .exposure
    
    var body: some View {
        VStack(spacing: 20) {
            // Target Toggle (Subject vs Background)
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
            
            // Active Tool Slider
            VStack(spacing: 8) {
                Text(selectedTool.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                activeSlider()
                    .padding(.horizontal, 30)
            }
            .frame(height: 50)
            
            // Tools Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(EditingTool.allCases) { tool in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTool = tool
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedTool == tool ? .primary : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedTool == tool ? Color.primary.opacity(0.1) : Color.clear)
                                    .clipShape(Circle())
                                
                                Text(tool.rawValue)
                                    .font(.system(size: 10, weight: selectedTool == tool ? .semibold : .regular))
                                    .foregroundColor(selectedTool == tool ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private func activeSlider() -> some View {
        switch selectedTool {
        case .exposure:
            Slider(value: $viewModel.activeExposure, in: -2.0...2.0)
        case .brightness:
            Slider(value: $viewModel.activeBrightness, in: -1.0...1.0)
        case .contrast:
            Slider(value: $viewModel.activeContrast, in: 0.25...4.0)
        case .highlights:
            Slider(value: $viewModel.activeHighlights, in: 0.3...1.7)
        case .shadows:
            Slider(value: $viewModel.activeShadows, in: -1.0...1.0)
        case .saturation:
            Slider(value: $viewModel.activeSaturation, in: 0.0...2.0)
        case .vibrance:
            Slider(value: $viewModel.activeVibrance, in: -1.0...1.0)
        case .warmth:
            Slider(value: $viewModel.activeTemperature, in: 2000.0...10000.0)
        case .tint:
            Slider(value: $viewModel.activeTint, in: -100.0...100.0)
        case .sharpness:
            Slider(value: $viewModel.activeSharpness, in: 0.0...10.0)
        }
    }
}
