//
//  DataViewController.swift
//  HaptiDrum_iPhone_v1
//
//  Created by Hongrui Wu  on 6/10/25.
//

import UIKit

class DataViewController: UIViewController {

    @IBAction func backButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBOutlet weak var footLLabel: UILabel!
    @IBOutlet weak var footRLabel: UILabel!
    @IBOutlet weak var handLLabel: UILabel!
    @IBOutlet weak var handRLabel: UILabel!

    let deviceNames = [
        "HaptiDrum_Foot_L": "Foot_L",
        "HaptiDrum_Foot_R": "Foot_R",
        "HaptiDrum_Hand_L": "Hand_L",
        "HaptiDrum_Hand_R": "Hand_R"
    ]

    var labelMap: [String: UILabel] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        labelMap = [
            "HaptiDrum_Foot_L": footLLabel,
            "HaptiDrum_Foot_R": footRLabel,
            "HaptiDrum_Hand_L": handLLabel,
            "HaptiDrum_Hand_R": handRLabel
        ]

        // 监听 BLE 数据
        BLEManager.shared.onDataReceived = { [weak self] peripheral, data in
            guard let self = self,
                  let name = peripheral.name,
                  let label = self.labelMap[name] else { return }

            let yaw = (data["yaw"] as? NSNumber)?.doubleValue ?? 0
            let pitch = (data["pitch"] as? NSNumber)?.doubleValue ?? 0
            let roll = (data["roll"] as? NSNumber)?.doubleValue ?? 0
            let gx = (data["gx"] as? NSNumber)?.doubleValue ?? 0
            let gy = (data["gy"] as? NSNumber)?.doubleValue ?? 0
            let gz = (data["gz"] as? NSNumber)?.doubleValue ?? 0

            let displayText = """
            Yaw: \(yaw)
            Pitch: \(pitch)
            Roll: \(roll)
            GX: \(gx)
            GY: \(gy)
            GZ: \(gz)
            """

            DispatchQueue.main.async {
                label.text = displayText
            }
        }
    }
}
