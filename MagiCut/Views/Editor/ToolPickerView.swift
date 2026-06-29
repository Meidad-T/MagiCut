import SwiftUI
import Photos

enum EditTab {
    case adjust, filters, crop, reimagine
}

struct AdjustSidebarView: View {
    @Bindable var viewModel: EditorViewModel
    
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
                
                // Adjustments
                VStack(spacing: 24) {
                    adjustmentRow(title: "Exposure", value: $viewModel.activeExposure, range: -2.0...2.0)
                    adjustmentRow(title: "Brightness", value: $viewModel.activeBrightness, range: -1.0...1.0)
                    adjustmentRow(title: "Contrast", value: $viewModel.activeContrast, range: 0.25...4.0)
                    adjustmentRow(title: "Highlights", value: $viewModel.activeHighlights, range: 0.3...1.7)
                    adjustmentRow(title: "Shadows", value: $viewModel.activeShadows, range: -1.0...1.0)
                    adjustmentRow(title: "Saturation", value: $viewModel.activeSaturation, range: 0.0...2.0)
                    adjustmentRow(title: "Vibrance", value: $viewModel.activeVibrance, range: -1.0...1.0)
                    adjustmentRow(title: "Warmth", value: $viewModel.activeTemperature, range: 2000.0...10000.0)
                    adjustmentRow(title: "Tint", value: $viewModel.activeTint, range: -100.0...100.0)
                    adjustmentRow(title: "Sharpness", value: $viewModel.activeSharpness, range: 0.0...10.0)
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
