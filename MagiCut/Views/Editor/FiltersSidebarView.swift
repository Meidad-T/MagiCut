import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum PhotoFilter: String, CaseIterable, Identifiable {
    case original = "Original"
    case vivid = "Vivid"
    case vividWarm = "Vivid Warm"
    case vividCool = "Vivid Cool"
    case dramatic = "Dramatic"
    case dramaticWarm = "Dramatic Warm"
    case dramaticCool = "Dramatic Cool"
    case mono = "Mono"
    case silvertone = "Silvertone"
    case noir = "Noir"
    case rainbowRed = "Rainbow Red"
    case rainbowOrange = "Rainbow Orange"
    case rainbowYellow = "Rainbow Yellow"
    case rainbowGreen = "Rainbow Green"
    case rainbowBlue = "Rainbow Blue"
    case rainbowIndigo = "Rainbow Indigo"
    case rainbowViolet = "Rainbow Violet"
    
    var id: String { rawValue }
    
    // CoreImage Filter Mapping
    var ciFilterName: String? {
        switch self {
        case .original: return nil
        case .vivid: return "CIPhotoEffectChrome" // Closest to Vivid
        case .vividWarm: return "CIPhotoEffectTransfer"
        case .vividCool: return "CIPhotoEffectProcess"
        case .dramatic: return "CIPhotoEffectFade"
        case .dramaticWarm: return "CIPhotoEffectInstant"
        case .dramaticCool: return "CIPhotoEffectProcess" // Dramatic cool approx
        case .mono: return "CIPhotoEffectMono"
        case .silvertone: return "CIPhotoEffectTonal"
        case .noir: return "CIPhotoEffectNoir"
        default: return "Custom" // Rainbows use custom CIHueAdjust
        }
    }
}

struct FiltersSidebarView: View {
    @Bindable var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            
            Text("FILTERS")
                .font(.caption)
                .bold()
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(PhotoFilter.allCases) { filter in
                        FilterRowView(filter: filter, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FilterRowView: View {
    let filter: PhotoFilter
    @Bindable var viewModel: EditorViewModel
    
    // Active filter name based on active target
    private var activeFilterName: String {
        switch viewModel.projectState.activeTarget {
        case .subject: return viewModel.projectState.subjectEdits.filterName
        case .background: return viewModel.projectState.backgroundEdits.filterName
        }
    }
    
    var isSelected: Bool {
        activeFilterName == filter.rawValue
    }
    
    var body: some View {
        Button(action: {
            // Apply filter
            switch viewModel.projectState.activeTarget {
            case .subject:
                viewModel.projectState.subjectEdits.filterName = filter.rawValue
            case .background:
                viewModel.projectState.backgroundEdits.filterName = filter.rawValue
            }
            viewModel.updateRenderedImage()
        }) {
            HStack(spacing: 16) {
                // Miniature thumbnail preview
                if let uiImage = viewModel.uiImage {
                    Image(platformImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                }
                
                Text(filter.rawValue)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.bold())
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
