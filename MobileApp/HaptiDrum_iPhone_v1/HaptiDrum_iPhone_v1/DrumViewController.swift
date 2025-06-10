//
//  DrumViewController.swift
//  HaptiDrum_iPhone_v1
//
//  Created by Hongrui Wu  on 5/1/25.
//

import UIKit
import AVFoundation



// IMU data structure of each device
struct IMUDevice {
    var baselineYaw: Double = 0
    var baselinePitch: Double = 0
    var baselineRoll: Double = 0

    var isCollectingBaseline: Bool = false
    var yawArray = [Double]()
    var pitchArray = [Double]()
    var rollArray = [Double]()

    var inHitZone: Bool = false
}


class DrumViewController: UIViewController {
    
    // 管理多个设备数据
    let deviceNames = ["HaptiDrum_Foot_L", "HaptiDrum_Foot_R", "HaptiDrum_Hand_L", "HaptiDrum_Hand_R"]
    var imuDevices: [String: IMUDevice] = [:]
    var drumImageViews: [String: UIImageView] = [:]
    
    var activePlayers: [AVAudioPlayer] = []


        

    @IBOutlet weak var drumImageView: UIImageView!
    @IBOutlet weak var bassDrumImageView: UIImageView!
    
//    var drumPlayer: AVAudioPlayer?
//    var bassDrumPlayer: AVAudioPlayer?
    var drumURL: URL?
    var bassDrumURL: URL?


    
    
    override func viewDidLoad() {
        
        // 图像设置...
        drumImageView.image = UIImage(named: "drum_off")
        bassDrumImageView.image = UIImage(named: "bassDrum_off")

        // 初始化播放器
        drumURL = Bundle.main.url(forResource: "drum", withExtension: "wav")
        bassDrumURL = Bundle.main.url(forResource: "bassDrum", withExtension: "wav")


        // 初始化每个设备状态
        for name in deviceNames {
            imuDevices[name] = IMUDevice()
        }

        // 映射设备名到图像
        drumImageViews = [
            "HaptiDrum_Hand_R": drumImageView,
            "HaptiDrum_Foot_R": bassDrumImageView
        ]
    }
    
    
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func resetButtonTapped(_ sender: UIButton) {
        let resetCommand = BLECommand(type: "RESET", payload: nil)
        let connected = BLEManager.shared.connectedPeripherals

        if connected.isEmpty {
            print("❌ No connected peripherals")
            return
        }

        for peripheral in connected {
            BLEManager.shared.sendCommand(resetCommand, to: peripheral)
            print("✅ Sent RESET to \(peripheral.name ?? "unknown")")
        }
    }

    
    // 设置 baseline
    @IBAction func initializationTapped(_ sender: UIButton) {
        for name in deviceNames {
            imuDevices[name]?.yawArray.removeAll()
            imuDevices[name]?.pitchArray.removeAll()
            imuDevices[name]?.rollArray.removeAll()
            imuDevices[name]?.isCollectingBaseline = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for name in self.deviceNames {
                guard var device = self.imuDevices[name] else { continue }
                device.isCollectingBaseline = false
                device.baselineYaw = device.yawArray.average
                device.baselinePitch = device.pitchArray.average
                device.baselineRoll = device.rollArray.average
                self.imuDevices[name] = device

                print("[\(name)] Baseline set: yaw=\(device.baselineYaw), pitch=\(device.baselinePitch), roll=\(device.baselineRoll)")
            }
        }
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        BLEManager.shared.onDataReceived = { [weak self] peripheral, data in
            guard let self = self else { return }
            guard let name = peripheral.name, self.deviceNames.contains(name) else { return }

//            guard let yaw = (data["yaw"] as? NSNumber)?.doubleValue,
//                  let pitch = (data["pitch"] as? NSNumber)?.doubleValue,
//                  let roll = (data["roll"] as? NSNumber)?.doubleValue,
//                  let gx = (data["gx"] as? NSNumber)?.doubleValue,
//                  let gy = (data["gy"] as? NSNumber)?.doubleValue,
//                  let gz = (data["gz"] as? NSNumber)?.doubleValue else { return }
            let yaw = (data["yaw"] as? NSNumber)?.doubleValue ?? 0
            let pitch = (data["pitch"] as? NSNumber)?.doubleValue ?? 0
            let roll = (data["roll"] as? NSNumber)?.doubleValue ?? 0
            let gx = (data["gx"] as? NSNumber)?.doubleValue ?? 0
            let gy = (data["gy"] as? NSNumber)?.doubleValue ?? 0
            let gz = (data["gz"] as? NSNumber)?.doubleValue ?? 0


            guard var device = self.imuDevices[name] else { return }

            if device.isCollectingBaseline {
                device.yawArray.append(yaw)
                device.pitchArray.append(pitch)
                device.rollArray.append(roll)
            }

            let adjYaw = yaw - device.baselineYaw
            let adjPitch = pitch - device.baselinePitch
            let adjRoll = roll - device.baselineRoll


            let inRange = abs(adjPitch) < 5 && abs(adjRoll) < 5

            if inRange && !device.inHitZone {
                print("[\(name)] 🥁 Drum Hit Detected!")
                device.inHitZone = true
                
                let soundMap: [String: URL?] = [
                    "HaptiDrum_Hand_R": drumURL,
                    "HaptiDrum_Foot_R": bassDrumURL
                ]

                if let soundURL = soundMap[name] ?? nil {
                    playSound(from: soundURL)
                }



                if let imageView = self.drumImageViews[name] {
                    DispatchQueue.main.async {
                        imageView.image = UIImage(named: imageView == self.bassDrumImageView ? "bassDrum_on" : "drum_on")
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        imageView.image = UIImage(named: imageView == self.bassDrumImageView ? "bassDrum_off" : "drum_off")
                    }
                }

            } else if !inRange {
                device.inHitZone = false
            }

            self.imuDevices[name] = device
        }
    }

    
//    func loadSound(named name: String) -> AVAudioPlayer? {
//        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
//            print("❌ Sound file \(name).wav not found.")
//            return nil
//        }
//
//        do {
//            let player = try AVAudioPlayer(contentsOf: url)
//            player.prepareToPlay()
//            return player
//        } catch {
//            print("❌ Failed to load sound \(name): \(error)")
//            return nil
//        }
//    }
    
    func playSound(from url: URL?) {
        guard let url = url else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            activePlayers.append(player)

            // 自动清理过时的播放器，防止内存泄漏
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) {
                if let index = self.activePlayers.firstIndex(of: player) {
                    self.activePlayers.remove(at: index)
                }
            }
        } catch {
            print("❌ Failed to play sound: \(error)")
        }
    }



    
    
    

    
}

// 平均值扩展
extension Array where Element == Double {
    var average: Double {
        return self.isEmpty ? 0 : self.reduce(0, +) / Double(self.count)
    }
}

