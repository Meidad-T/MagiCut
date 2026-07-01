import CoreGraphics

let t = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
let p0 = CGPoint(x: 0, y: 0)
let p1 = CGPoint(x: 0, y: 1)

print("p0 mapped:", p0.applying(t))
print("p1 mapped:", p1.applying(t))
