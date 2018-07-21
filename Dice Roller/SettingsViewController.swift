import UIKit

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var d4CountLabel: UILabel!
    @IBOutlet weak var d6CountLabel: UILabel!
    @IBOutlet weak var d8CountLabel: UILabel!
    @IBOutlet weak var d10CountLabel: UILabel!
    @IBOutlet weak var d12CountLabel: UILabel!
    @IBOutlet weak var d20CountLabel: UILabel!
    
    @IBOutlet weak var soundsSwitch: UISwitch!
    @IBOutlet weak var motionSwitch: UISwitch!
    
    
    let MAX_DICE = 20
    
    override func viewDidLoad() {
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.viewTapped)))
        
        //TODO load settings
    }
    
    @objc private func viewTapped() {
        dismiss(animated: true)
    }
    
    @IBAction func dieToggle(_ sender: UIButton) {
        let stack = sender.superview as! UIStackView
        let rowLabel = stack.arrangedSubviews.first as! UILabel
        let countLabel = stack.arrangedSubviews[2] as! UILabel
        
        let type = String(rowLabel.text!.dropLast())
        let oldCount = DiceManager.shared.diceCounts[type]!
        var newCount = 0
        if (sender.title(for: .normal) == "-") {
            if (oldCount <= 0) {
                return
            }
            newCount = oldCount - 1
            DiceManager.shared.removeDie(type: type)
        }
        else {
            if (oldCount >= MAX_DICE) {
                return
            }
            newCount = oldCount + 1
            DiceManager.shared.addDie(type: type)
            
        }
        countLabel.text = String(newCount)
    }
}
