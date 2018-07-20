import UIKit
import SceneKit
import SpriteKit
import CoreMotion

class GameViewController: UIViewController {
    
    var scnView: SCNView?
    var skScene: SKScene?
    
//    var d4Node:SCNNode!
//    var d6Node:SCNNode!
//    var d8Node:SCNNode!
//    var d10Node:SCNNode!
//    var d12Node:SCNNode!
    
    let stopped = SCNVector3()
    
    var grabbedDie: SCNNode?
    var grabLastPos: CGPoint?
    
    var diceNodes = [SCNNode]()
    var rollLabels = [SCNNode:SKLabelNode]()
    var grabbedVelocity = SCNVector3()
    var grabVelocityLastSet: Double?
    
    let layFlatMessage = SKShapeNode()
    var layFlatCount = 0
    
    let motionManager = CMMotionManager()
    var accel = CMAcceleration()
    
    var lastCheckedMovement: TimeInterval = 0
    var diceMoving = [SCNNode : Bool]()
    var diceLastMoveCheckLocations = [SCNNode : SCNVector3]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (motionManager.isAccelerometerAvailable) {
//            motionManager.deviceMotionUpdateInterval = 0.1
//            motionManager.startDeviceMotionUpdates(to: OperationQueue(), withHandler: handleAccelerations)
            motionManager.accelerometerUpdateInterval = 1.0/60
            motionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler: handleAccelerations)
        }
        
        skScene = SKScene(size: view.bounds.size)
        
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
            diceMoving[dieNode] = true
            let label = SKLabelNode()
            let labelContainer = SKShapeNode()
            labelContainer.fillColor = .black
            labelContainer.strokeColor = .black
            labelContainer.alpha = 0.9
            rollLabels[dieNode] = label
            labelContainer.addChild(label)
            skScene?.addChild(labelContainer)
        }
        
        let floor = scene.rootNode.childNode(withName: "floor", recursively: true)!
        floor.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(1.5, 1.5, 1.5), SCNMatrix4MakeTranslation(0.7, 0.75, 0))
        floor.geometry?.firstMaterial?.diffuse.wrapS = .repeat
        floor.geometry?.firstMaterial?.diffuse.wrapT = .repeat
        
        addLayFlatMessage()
        
        self.scnView = self.view as? SCNView
        scnView?.overlaySKScene = skScene!
        
        scnView!.scene = scene
        
        scnView!.delegate = self
        
        // show statistics such as fps and timing information
//        scnView!.showsStatistics = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView!.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView!.addGestureRecognizer(panGesture)
    }
    
    private func addLayFlatMessage() {
        let label = SKLabelNode(text: "Warning - Lay phone flat")
        let label2 = SKLabelNode(text: "so dice can settle")
        let center = CGPoint(x: skScene!.size.width / 2, y: skScene!.size.height / 2)
        label.position = CGPoint(x: center.x + 2.0, y: center.y + 7)
        label2.position = CGPoint(x: center.x + 2.0, y: center.y - 23)
        label.fontColor = .red
        label2.fontColor = .red
        layFlatMessage.fillColor = .black
        layFlatMessage.strokeColor = .black
        layFlatMessage.alpha = 0.9
        layFlatMessage.path =
            CGPath(roundedRect:
                CGRect(origin: CGPoint(x: center.x - label.frame.size.width/2.0, y: center.y - label.frame.size.height),
                       size: CGSize(width: label.frame.size.width + 4, height: label.frame.size.height * 2 + 4)), cornerWidth: 5, cornerHeight: 5, transform: nil)
        layFlatMessage.addChild(label)
        layFlatMessage.addChild(label2)
        skScene?.addChild(layFlatMessage)
        layFlatMessage.isHidden = true
    }
    
    @objc func handlePan(_ recognizer: UIGestureRecognizer) {
        if (recognizer.state == .began) {
            if let die = getTouchedDie(recognizer) {
                grabbedDie = die
                grabbedDie!.physicsBody?.velocity = stopped
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
    
    private func handleAccelerations(accelData: CMAccelerometerData?, err: Error?) {
        if let accelData = accelData {
            accel = accelData.acceleration
            if (Float.random < 0.1) {
                if (accel.z > -0.85 || abs(accel.x) > 0.2 || abs(accel.y) > 0.2) {
                    layFlatCount += 1
                    if (layFlatCount > 5) {
                        layFlatMessage.isHidden = false
                    }
                }
                else {
                    layFlatCount = 0
                    layFlatMessage.isHidden = true
                }
            }
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
        if (time > lastCheckedMovement + 0.5) {
            lastCheckedMovement = time
            diceNodes.forEach { die in
                detectChangeInStoppedness(die)
            }
        }
    }
    
    func didMove(_ die: SCNNode) -> Bool {
        let currentLocation = die.presentation.worldPosition
        let lastLocationOptional = diceLastMoveCheckLocations[die]
        diceLastMoveCheckLocations[die] = currentLocation
        
        guard let lastLocation = lastLocationOptional else {
            return true
        }
        
        return !areSuperClose(currentLocation, lastLocation)
    }
    
    func areSuperClose(_ a: SCNVector3, _ b: SCNVector3) -> Bool {
        return abs(a.x - b.x) < 0.05 && abs(a.y - b.y) < 0.05 && abs(a.z - b.z) < 0.05
    }
    
    func detectChangeInStoppedness(_ die: SCNNode){
        let wasMoving = diceMoving[die] ?? false
        if (wasMoving) {
            if (!didMove(die)) {
                handleStop(die)
            }
            return
        }
        
        if (didMove(die)) {
            handleStart(die)
        }
    }
    
    func handleStop(_ die: SCNNode) {
        diceMoving[die] = false
        let rolledFace = getFaceForRoll(die: die)
        
        let twoDPoint = scnView!.projectPoint(die.presentation.worldPosition)
        var skPoint = skScene!.convertPoint(fromView: CGPoint(x: CGFloat(twoDPoint.x), y: CGFloat(twoDPoint.y)))
        if (skPoint.y > 400) {
            skPoint.y -= 50
        }
        else {
            skPoint.y += 30
        }
        let label = rollLabels[die]!
        label.text = rolledFace
        label.position = CGPoint(x: skPoint.x + 2.0, y: skPoint.y + 2.0)
        let labelContainer = label.parent as! SKShapeNode
        labelContainer.path =
            CGPath(roundedRect:
                CGRect(origin: CGPoint(x: skPoint.x - label.frame.size.width/2.0, y: skPoint.y),
                       size: CGSize(width: label.frame.size.width + 4, height: label.frame.size.height + 4)), cornerWidth: 5, cornerHeight: 5, transform: nil)
        labelContainer.isHidden = false
    }
    
    func handleStart(_ die: SCNNode) {
        diceMoving[die] = true
        rollLabels[die]!.parent!.isHidden = true
    }
    
    func getFaceForRoll(die: SCNNode) -> String {
        var multiplier: Float = 1
        if (die.name == "d4") {
            multiplier = -1
        }
        var highestY: Float = -999.0
        var faceName = "x-unknown"
        die.childNodes.forEach { side in
            let newY = side.presentation.worldPosition.y * multiplier
            if (newY > highestY) {
                faceName = side.name ?? "x-unnamed face"
                highestY = newY
            }
        }
        let side = faceName.suffix(from: faceName.index(after: faceName.index(of: "-")!))
        return String(side)
    }
}
