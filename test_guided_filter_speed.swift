import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

let context = CIContext(options: [.cacheIntermediates: false, .useSoftwareRenderer: false])

// Create a dummy guide image 1024x1024 (checkerboard)
let checker = CIFilter.checkerboardGenerator()
checker.color0 = CIColor.black
checker.color1 = CIColor.white
checker.width = 100
let guide = checker.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 1024, height: 1024))

// Create a dummy mask image
let maskFilter = CIFilter.gaussianGradient()
maskFilter.center = CGPoint(x: 512, y: 512)
maskFilter.radius = 300
maskFilter.color0 = CIColor.white
maskFilter.color1 = CIColor.black
let mask = maskFilter.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 1024, height: 1024))

let start = Date()
let filter = CIFilter(name: "CIGuidedFilter")!
filter.setValue(mask, forKey: kCIInputImageKey)
filter.setValue(guide, forKey: "inputGuideImage")
filter.setValue(NSNumber(value: 20), forKey: "inputRadius")
filter.setValue(NSNumber(value: 0.001), forKey: "inputEpsilon")

let output = filter.outputImage!

if let cgImage = context.createCGImage(output, from: output.extent) {
    let elapsed = Date().timeIntervalSince(start)
    print("Guided filter executed in \(elapsed) seconds. Output size: \(cgImage.width)x\(cgImage.height)")
} else {
    print("Failed")
}
