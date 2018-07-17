import SceneKit


extension SCNVector3 {
    var isZero: Bool {
        return x.isZero && y.isZero && z.isZero
    }
}
