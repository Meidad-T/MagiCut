import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum PhotoFilter: String, CaseIterable, Identifiable {
    case original = "Original"
    case vivid = "Vivid"
    case oldTV = "Old TV"
    case halftone = "Halftone Print"
    case hardOutline = "Hard Outline"
    case comic = "Comic Book"
    case paintCrystallize = "Crystal Paint"
    case paintPointillize = "Pointillism"
    case retro8Bit = "8-Bit Retro"
    case highContrastBW = "High Contrast B&W"
    case posterize = "Posterize"
    
    var id: String { rawValue }
    
    // CoreImage Filter Mapping
    var ciFilterName: String? {
        switch self {
        case .original: return nil
        case .vivid: return "CIPhotoEffectChrome"
        case .oldTV: return "Custom"
        case .halftone: return "Custom"
        case .hardOutline: return "Custom"
        case .comic: return "CIComicEffect"
        case .paintCrystallize: return "Custom"
        case .paintPointillize: return "Custom"
        case .retro8Bit: return "Custom"
        case .highContrastBW: return "Custom"
        case .posterize: return "Custom"
        }
    }
}

struct FiltersSidebarView: View {
    @Bindable var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Target Selection Toggles
            HStack(spacing: 12) {
                Button(action: {
                    if viewModel.projectState.activeTarget == .subject {
                        viewModel.setTarget(.wholeImage)
                    } else {
                        viewModel.setTarget(.subject)
                    }
                }) {
                    Text("Subject")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.projectState.activeTarget == .subject ? Color.yellow : Color.gray.opacity(0.2))
                        .foregroundColor(viewModel.projectState.activeTarget == .subject ? .black : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if viewModel.projectState.activeTarget == .background {
                        viewModel.setTarget(.wholeImage)
                    } else {
                        viewModel.setTarget(.background)
                    }
                }) {
                    Text("Background")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.projectState.activeTarget == .background ? Color.yellow : Color.gray.opacity(0.2))
                        .foregroundColor(viewModel.projectState.activeTarget == .background ? .black : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
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
    
    @State private var previewImage: PlatformImage?
    
    // Active filter name based on active target
    private var activeFilterName: String {
        switch viewModel.projectState.activeTarget {
        case .wholeImage: return viewModel.projectState.wholeImageEdits.filterName
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
            case .wholeImage:
                viewModel.projectState.wholeImageEdits.filterName = filter.rawValue
            case .subject:
                viewModel.projectState.subjectEdits.filterName = filter.rawValue
            case .background:
                viewModel.projectState.backgroundEdits.filterName = filter.rawValue
            }
            viewModel.updateRenderedImage()
        }) {
            HStack(spacing: 16) {
                // Miniature thumbnail preview
                if let preview = previewImage {
                    Image(platformImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                } else if let uiImage = viewModel.uiImage {
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
        .task(id: viewModel.projectState.activeTarget) {
            previewImage = await viewModel.generateFilterPreview(for: filter.rawValue)
        }
    }
}
