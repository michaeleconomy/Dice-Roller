import UIKit
import SceneKit
import CoreMotion

class GameViewController: UIViewController {
    
    var scnView: SCNView?
    
//    var d4Node:SCNNode!
//    var d6Node:SCNNode!
//    var d8Node:SCNNode!
//    var d10Node:SCNNode!
//    var d12Node:SCNNode!
    
    var grabbedDie: SCNNode?
    var grabLastPos: CGPoint?
    
    var diceNodes = [SCNNode]()
    var grabbedVelocity = SCNVector3()
    var grabVelocityLastSet: Double?
    
    let motionManager = CMMotionManager()
    var accel = CMAcceleration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (motionManager.isAccelerometerAvailable) {
//            motionManager.deviceMotionUpdateInterval = 0.1
//            motionManager.startDeviceMotionUpdates(to: OperationQueue(), withHandler: handleAccelerations)
            motionManager.accelerometerUpdateInterval = 1.0/60
            motionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler: handleAccelerations)
        }
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/dice.scn")!
        ["d4", "d6", "d8", "d10", "d12", "d20"].forEach { die in
            let dieNode = scene.rootNode.childNode(withName: die, recursively: true)!
            let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: dieNode.geometry!, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.convexHull]))
            physicsBody.isAffectedByGravity = false
            physicsBody.friction = 0.95
            physicsBody.angularDamping = 0.02
            physicsBody.damping = 0.05
            physicsBody.restitution = 0.9
            dieNode.physicsBody = physicsBody
            let mat = SCNMaterial()
            mat.diffuse.contents = UIImage(named: "daes.scnassets/\(die)texture.png")
            dieNode.geometry?.insertMaterial(mat, at: 0)
            diceNodes.append(dieNode)
        }
        
//        scnView.allowsCameraControl = true
        
        
//        // create and add a camera to the scene
//        let cameraNode = SCNNode()
//        cameraNode.camera = SCNCamera()
//        scene.rootNode.addChildNode(cameraNode)
//
//        // place the camera
//        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
//        // create and add a light to the scene
//        let lightNode = SCNNode()
//        lightNode.light = SCNLight()
//        lightNode.light!.type = .omni
//        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
//        scene.rootNode.addChildNode(lightNode)
//
//        // create and add an ambient light to the scene
//        let ambientLightNode = SCNNode()
//        ambientLightNode.light = SCNLight()
//        ambientLightNode.light!.type = .ambient
//        ambientLightNode.light!.color = UIColor.darkGray
//        scene.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the ship node
//        let ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        
        // animate the 3d object
//        ship.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
        
        // retrieve the SCNView
        self.scnView = self.view as? SCNView
        
        // set the scene to the view
        scnView!.scene = scene
        
        scnView!.delegate = self
        
        // show statistics such as fps and timing information
        scnView!.showsStatistics = true
        
        // configure the view
        scnView!.backgroundColor = UIColor.blue
        
        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView!.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView!.addGestureRecognizer(panGesture)
    }
    
    @objc func handlePan(_ recognizer: UIGestureRecognizer) {
        if (recognizer.state == .began) {
            if let die = getTouchedDie(recognizer) {
                grabbedDie = die
                grabbedDie!.physicsBody?.velocity = SCNVector3()
                grabbedDie!.physicsBody?.type = .static
                grabbedDie!.worldPosition = SCNVector3(x: grabbedDie!.presentation.worldPosition.x, y: grabbedDie!.presentation.worldPosition.y, z: grabbedDie!.presentation.worldPosition.z)
                grabLastPos = recognizer.location(in: scnView!)
            }
            return
        }
        if let grabbedDie = grabbedDie {
            if (recognizer.state == .changed) {
                let currentLoc = recognizer.location(in: scnView!)
                let xdiff = Float(grabLastPos!.x - currentLoc.x)/100
                let ydiff = Float(grabLastPos!.y - currentLoc.y)/100
                self.grabLastPos = currentLoc
                
                if let grabVelocityLastSet = grabVelocityLastSet {
                    let timeDiff = Float(CACurrentMediaTime() - grabVelocityLastSet) * 10
                    grabbedVelocity = SCNVector3(x: ydiff / timeDiff * 10 , y: 0, z: -xdiff / timeDiff)
                }
                grabVelocityLastSet = CACurrentMediaTime()
                grabbedDie.worldPosition = SCNVector3(x: grabbedDie.worldPosition.x + ydiff, y: grabbedDie.worldPosition.y, z: grabbedDie.worldPosition.z - xdiff)
                return
            }
            if (recognizer.state == .ended) {
                grabbedDie.physicsBody?.type = .dynamic
                grabbedDie.physicsBody?.velocity = grabbedVelocity
//
//                let currentLoc = recognizer.location(in: scnView!)
                self.grabbedDie = nil
                return
            }
        }
    }
    
    @objc func handleTap(_ recognizer: UIGestureRecognizer) {
        if let die = getTouchedDie(recognizer) {
            die.physicsBody?.applyForce(SCNVector3(x: (Float.random * 10) - 5, y: (Float.random * 5.0) + 2, z: (Float.random * 10) - 5), asImpulse: true)
            return
        }
        
        diceNodes.forEach { die in
            die.physicsBody?.applyForce(SCNVector3(x: (Float.random * 10) - 5, y: (Float.random * 5.0) + 2, z: (Float.random * 10) - 5), asImpulse: true)
        }
    }
    
    private func getTouchedDie(_ recognizer: UIGestureRecognizer) -> SCNNode? {
        let location = recognizer.location(in: scnView!)
        
        let hitResults = scnView!.hitTest(location, options: nil)
        
        if hitResults.count > 0 {
            let result = hitResults.first
            if let node = result?.node {
                if (node.name?.starts(with: "d") ?? false) {
                    return node
                }
            }
        }
        
        return nil
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
//    private func handleAccelerations(deviceMotion: CMDeviceMotion?, err: Error?) {
//        if let deviceMotion = deviceMotion {
//            accel = deviceMotion.userAcceleration
////            NSLog("accel: %f %f %f", accel.x, accel.y, accel.z)
////            let sum = abs(accel.x) + abs(accel.y) + abs(accel.z)
////            if (sum > 0.01) {
//
////            }
//        }
//    }
    
    private func handleAccelerations(accelData: CMAccelerometerData?, err: Error?) {
        if let accelData = accelData {
            accel = accelData.acceleration
        }
    }
}

extension GameViewController: SCNSceneRendererDelegate {

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        diceNodes.forEach { die in
            if (die.name != grabbedDie?.name) {
                die.physicsBody?.applyForce(SCNVector3(x: Float(accel.y), y: Float(accel.z), z: Float(accel.x)), asImpulse: false)
            }
        }
    }

}
