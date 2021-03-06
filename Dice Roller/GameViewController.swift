import UIKit
import SceneKit
import SpriteKit
import CoreMotion

class GameViewController: UIViewController {
    
    var scnView: SCNView?
    var skScene: SKScene?
    let settingsButton = SKSpriteNode(imageNamed: "gears")
    
    let scene = SCNScene(named: "art.scnassets/dice.scn")!
    
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
    
    var diceContactSoundsActions = [(SCNAudioSource, SCNAction)]()
    var tableContactSoundsActions = [(SCNAudioSource, SCNAction)]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DiceManager.shared.delegate = self
        
        if (motionManager.isAccelerometerAvailable) {
            motionManager.accelerometerUpdateInterval = 1.0/60
            motionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler: handleAccelerations)
        }
        
        skScene = SKScene(size: view.bounds.size)
        setupSounds()
        
        ["d4", "d6", "d8", "d10", "d12", "d20"].forEach { dieName in
            let die = scene.rootNode.childNode(withName: dieName, recursively: true)!
            let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: die.geometry!, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.convexHull]))
            physicsBody.isAffectedByGravity = false
            physicsBody.friction = 0.95
            physicsBody.angularDamping = 0.02
            physicsBody.damping = 0.05
            physicsBody.restitution = 0.9
            physicsBody.contactTestBitMask = 0xFFFF
            die.physicsBody = physicsBody
            let mat = SCNMaterial()
            mat.diffuse.contents = UIImage(named: "daes.scnassets/\(dieName)texture.png")
            die.geometry?.insertMaterial(mat, at: 0)
            diceNodes.append(die)
            diceMoving[die] = true
            makeRollLabel(die)
            
            var count = 1
            let settingsCount = DiceManager.shared.diceCounts[dieName]!
            if (settingsCount == 0) {
                removeDie(type: dieName)
            }
            
            while (count < settingsCount) {
                addDie(type: dieName)
                count += 1
            }
        }
        
        configureFloor()
        
        addLayFlatMessage()
        
        
        //add settings button
        settingsButton.position = CGPoint(x: skScene!.size.width - 20, y: skScene!.size.height - 20)
        skScene?.addChild(settingsButton)
        
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
        
        scene.physicsWorld.contactDelegate = self
    }
    
    private func setupSounds() {
        
        let diceContactSounds: [SCNAudioSource] = [SCNAudioSource(named: "art.scnassets/sounds/dice_contact1.m4a")!, SCNAudioSource(named: "art.scnassets/sounds/dice_contact2.m4a")!]
        let tableContactSounds: [SCNAudioSource] = [SCNAudioSource(named: "art.scnassets/sounds/table_contact1.m4a")!, SCNAudioSource(named: "art.scnassets/sounds/table_contact2.m4a")!, SCNAudioSource(named: "art.scnassets/sounds/table_contact3.m4a")!]
        
        diceContactSounds.forEach { audioSource in
            let action = SCNAction.playAudio(audioSource, waitForCompletion: false)
            diceContactSoundsActions.append((audioSource, action))
        }
        
        tableContactSounds.forEach { audioSource in
            let action = SCNAction.playAudio(audioSource, waitForCompletion: false)
            tableContactSoundsActions.append((audioSource, action))
        }
    }
    
    private func configureFloor() {
        guard let floor = scene.rootNode.childNode(withName: "floor", recursively: true) else {
            NSLog("error: floor not found")
            return
        }
        floor.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(1.5, 1.5, 1.5), SCNMatrix4MakeTranslation(0.7, 0.75, 0))
        floor.geometry?.firstMaterial?.diffuse.wrapS = .repeat
        floor.geometry?.firstMaterial?.diffuse.wrapT = .repeat
    }
    
    private func makeRollLabel(_ die: SCNNode) {
        let label = SKLabelNode()
        let labelContainer = SKShapeNode()
        labelContainer.fillColor = .black
        labelContainer.strokeColor = .black
        labelContainer.alpha = 0.9
        rollLabels[die] = label
        labelContainer.addChild(label)
        skScene?.addChild(labelContainer)
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
        
        let firstTouchPoint = recognizer.location(ofTouch: 0, in: nil)
        let skNode = skScene!.atPoint(skScene!.convertPoint(fromView: firstTouchPoint))
        if skNode == settingsButton {
            performSegue(withIdentifier: "settings", sender: nil)
            return
        }
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
                    if (layFlatCount > 5 && DiceManager.shared.motion) {
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
        var accelToUse = SCNVector3(x: Float(accel.y) * 2, y: Float(accel.z) * 2, z: Float(accel.x) * 2)
        if (!DiceManager.shared.motion) {
            accelToUse = SCNVector3(x: 0.0, y: -2.0, z: 0.0)
        }
        diceNodes.forEach { die in
            if (die !== grabbedDie) {
                die.physicsBody?.applyForce(accelToUse, asImpulse: false)
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
        if (die.name!.starts(with: "d4")) {
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

extension GameViewController: DiceWatcher {
    
    func addDie(type: String) {
        let original = scene.rootNode.childNode(withName: type, recursively: true)!
        if (original.isHidden) {
            NSLog("unhiding original \(type)")
            original.isHidden = false
            diceNodes.append(original)
            return
        }
        NSLog("creating a new \(type)")
        let die = original.clone()
        die.worldPosition = SCNVector3(x: 0.0, y: 2.0, z: 0.0)
//        die.presentation.worldPosition = SCNVector3()
        die.name = "\(type)-copy"
        diceMoving[die] = true
        makeRollLabel(die)
        scene.rootNode.addChildNode(die)
        diceNodes.append(die)
    }
    
    func removeDie(type: String) {
        scene.isPaused = true
        if let copy = scene.rootNode.childNode(withName: "\(type)-copy", recursively: true) {
            NSLog("removing a \(type)")
            
            let index = diceNodes.index(of: copy)!
            diceNodes.remove(at: index)
            diceMoving.removeValue(forKey: copy)
            let label = rollLabels.removeValue(forKey: copy)!
            label.parent?.removeFromParent()
            copy.removeFromParentNode()
            
            scene.isPaused = false
            return
        }
        NSLog("hiding original \(type)")
        let die = scene.rootNode.childNode(withName: type, recursively: true)!
        
        let index = diceNodes.index(of: die)!
        diceNodes.remove(at: index)
        let label = rollLabels[die]!
        label.parent!.isHidden = true
        die.isHidden = true
        scene.isPaused = false
    }
    
    func turnOnMotion() {
        //nothing
    }
    
    func turnOffMotion() {
        layFlatMessage.isHidden = false
    }
    
    func turnOnSounds() {
        //nothing
    }
    
    func turnOffSounds() {
        //nothing
    }
}

extension GameViewController: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        if (!DiceManager.shared.sounds) {
            return
        }
        let nodeAIsDie = contact.nodeA.name?.starts(with: "d") ?? false
        let nodeBIsDie = contact.nodeB.name?.starts(with: "d") ?? false
        let die = nodeAIsDie ? contact.nodeA : contact.nodeB
        if (contact.collisionImpulse > 0.1 && !die.isHidden) {
            let randIndex = Int(arc4random_uniform(UInt32(diceContactSoundsActions.count)))
            var (audioSource, action) = diceContactSoundsActions[randIndex]
            if (!nodeAIsDie || !nodeBIsDie) {
                let randIndex = Int(arc4random_uniform(UInt32(tableContactSoundsActions.count)))
                (audioSource, action) = tableContactSoundsActions[randIndex]
            }
            
            audioSource.volume = Float(contact.collisionImpulse * 3.0)
            if (audioSource.volume > 50.0) {
                audioSource.volume = 50.0
            }
            die.runAction(action)
//            NSLog("\(contact.nodeA.name ?? "unknown") contacted \(contact.nodeB.name ?? "unknown")  contact.collisionImpulse: \(contact.collisionImpulse)")
        }
    }
}

