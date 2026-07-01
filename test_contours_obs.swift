import Vision

func test(obs: VNContoursObservation) {
    let contours = obs.topLevelContours
    let contour = try? obs.contour(at: IndexPath(index: 0))
    print(contours)
}
