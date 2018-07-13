import UIKit
import SceneKit
import CoreMotion

class GameViewController: UIViewController {
    
    var d4Node:SCNNode!
    var d6Node:SCNNode!
    var d8Node:SCNNode!
    var d10Node:SCNNode!
    var d12Node:SCNNode!
    var d20Node:SCNNode!
    var pyramidNode:SCNNode!
    var diceNodes = [SCNNode]()
    
    
    let motionManager = CMMotionManager()
    var accel = CMAcceleration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (motionManager.isAccelerometerAvailable) {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: OperationQueue(), withHandler: handleAccelerations)
        }
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/dice.scn")!
        
        d6Node = scene.rootNode.childNode(withName: "d6", recursively: true)!
        pyramidNode = scene.rootNode.childNode(withName: "pyramid", recursively: true)!
        d20Node = scene.rootNode.childNode(withName: "d20", recursively: true)!
        d8Node = scene.rootNode.childNode(withName: "d8", recursively: true)!
        d8Node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: d8Node.geometry!, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.convexHull]))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIImage(named: "daes.scnassets/d8 texture.png")
        d8Node.geometry?.replaceMaterial(at: 0, with: mat)
        
        diceNodes.append(contentsOf: [d6Node, d20Node, pyramidNode, d8Node])
        
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
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        
        scnView.delegate = self
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = UIColor.blue
        
        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        
        diceNodes.forEach { die in
            die.physicsBody?.applyForce(SCNVector3(x: (Float.random * 10) - 5, y: Float.random * 5, z: (Float.random * 10) - 5), asImpulse: true)
        }
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
    
    private func handleAccelerations(deviceMotion: CMDeviceMotion?, err: Error?) {
        if let deviceMotion = deviceMotion {
            accel = deviceMotion.userAcceleration
//            NSLog("accel: %f %f %f", accel.x, accel.y, accel.z)
//            let sum = abs(accel.x) + abs(accel.y) + abs(accel.z)
//            if (sum > 0.01) {
            
//            }
        }
    }
}

extension GameViewController: SCNSceneRendererDelegate {

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        diceNodes.forEach { die in
            die.physicsBody?.applyForce(SCNVector3(x: Float(accel.x), y: Float(accel.y), z: Float(accel.z)), asImpulse: true)
        }
    }

}
