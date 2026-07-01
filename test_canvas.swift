import SwiftUI

struct TestView: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.addLine(to: CGPoint(x: 100, y: 100))
            
            let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
            let gradient = Gradient(colors: rainbowColors)
            let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
            
            var wideGlow = context
            wideGlow.addFilter(.blur(radius: 6))
            wideGlow.stroke(path, with: .conicGradient(gradient, center: centerPoint), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
        }
    }
}
