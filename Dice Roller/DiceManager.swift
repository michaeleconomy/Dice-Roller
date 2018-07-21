import Foundation

protocol DiceWatcher {
    func addDie(type: String)
    func removeDie(type: String)
    
    func turnOnMotion()
    func turnOffMotion()
    
    func turnOnSounds()
    func turnOffSounds()
}

class DiceManager {
    static let shared = DiceManager()
    
    var diceCounts = ["d4": 1,
                      "d6": 1,
                      "d8": 1,
                      "d10": 1,
                      "d12": 1,
                      "d20": 1]
    
    var sounds = true
    var motion = true
    
    var delegate: DiceWatcher?
    
    init() {
        diceCounts.forEach { type, count in
            if let storedValue = UserDefaults.standard.string(forKey: type) {
                diceCounts[type] = Int(storedValue)!
            }
        }
        sounds = !UserDefaults.standard.bool(forKey: "soundsOff")
        motion = !UserDefaults.standard.bool(forKey: "motionOff")
    }
    
    func addDie(type: String) {
        let newCount = diceCounts[type]! + 1
        diceCounts[type] = newCount
        UserDefaults.standard.set(newCount, forKey: type)
        delegate?.addDie(type: type)
    }
    
    func removeDie(type: String) {
        let newCount = diceCounts[type]! - 1
        if (newCount < 0) {
            return
        }
        diceCounts[type] = newCount
        UserDefaults.standard.set(newCount, forKey: type)
        delegate?.removeDie(type: type)
    }
    
    func turnOffMotion() {
        motion = false
        UserDefaults.standard.set(true, forKey: "motionOff")
        delegate?.turnOffMotion()
    }
    
    func turnOnMotion() {
        motion = true
        UserDefaults.standard.set(false, forKey: "motionOff")
        delegate?.turnOnMotion()
    }
    
    
    func turnOffSounds() {
        sounds = false
        UserDefaults.standard.set(true, forKey: "soundsOff")
        delegate?.turnOffSounds()
    }
    
    func turnOnSounds() {
        sounds = true
        UserDefaults.standard.set(false, forKey: "soundsOff")
        delegate?.turnOnSounds()
    }
}
