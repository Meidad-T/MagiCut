import SwiftUI
import ImagePlayground

struct ReimagineSidebarView: View {
    @Bindable var viewModel: EditorViewModel
    @State private var promptText = ""
    @State private var isGenerating = false
    
    // Apple Intelligence ImagePlayground state
    @State private var showImagePlayground = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Re-imagine")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            Text("Describe what you want to generate. Powered by Apple Intelligence.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Glowing Text Field
            TextField("A snowy mountain background...", text: $promptText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .padding(.horizontal)
                .onSubmit {
                    startGeneration()
                }
            
            Button(action: {
                startGeneration()
            }) {
                HStack {
                    Spacer()
                    if isGenerating {
                        ProgressView().controlSize(.small)
                            .padding(.trailing, 4)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isGenerating ? "Generating..." : "Generate")
                        .bold()
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(promptText.isEmpty || isGenerating ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundColor(promptText.isEmpty || isGenerating ? .secondary : .white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(promptText.isEmpty || isGenerating)
            .padding(.horizontal)
            
            Spacer()
        }
        // Fallback or hook into official API if needed
        .imagePlaygroundSheet(isPresented: $showImagePlayground, concept: promptText, sourceImage: nil) { url in
            // Handle returned generated image URL from Apple Intelligence
            isGenerating = false
        } onCancellation: {
            isGenerating = false
        }
    }
    
    private func startGeneration() {
        guard !promptText.isEmpty else { return }
        isGenerating = true
        // In a real integration without UI, we might use ImageCreator programmatically.
        // For now, we present the sheet natively or mock the animation.
        showImagePlayground = true
    }
}
