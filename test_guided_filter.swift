import Foundation
import CoreImage

let context = CIContext()
if let filter = CIFilter(name: "CIGuidedFilter") {
    print("Guided filter exists: \(filter)")
    print("Attributes: \(filter.attributes)")
} else {
    print("No CIGuidedFilter")
}
