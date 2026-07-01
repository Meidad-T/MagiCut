import Vision

let req = VNGenerateForegroundInstanceMaskRequest()
print("Properties:")
let mirror = Mirror(reflecting: req)
for child in mirror.children {
    print(child.label ?? "", child.value)
}
