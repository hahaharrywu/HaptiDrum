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

    // For future volume use
    var gx: Double = 0
    var gy: Double = 0
    var gz: Double = 0
}



class DrumViewController: UIViewController {
    
    // 管理多个设备数据
    let deviceNames = ["HaptiDrum_Foot_L", "HaptiDrum_Foot_R", "HaptiDrum_Hand_L", "HaptiDrum_Hand_R"]
    var imuDevices: [String: IMUDevice] = [:]
    var drumImageViews: [String: UIImageView] = [:]
    
    var activePlayers: [AVAudioPlayer] = []


        

    @IBOutlet weak var drumImageView: UIImageView!
    @IBOutlet weak var kickDrumImageView: UIImageView!
    @IBOutlet weak var hihatImageView: UIImageView!
    @IBOutlet weak var drum2ImageView: UIImageView!
    
    
//    var drumPlayer: AVAudioPlayer?
//    var kickDrumPlayer: AVAudioPlayer?
    var drumURL: URL?
    var kickDrumURL: URL?
    var hiHatURL: URL?
    var drum2URL: URL?


    
    
    override func viewDidLoad() {
        
        // 图像设置...
        drumImageView.image = UIImage(named: "drum_off")
        kickDrumImageView.image = UIImage(named: "kickDrum_off")
        hihatImageView.image = UIImage(named: "hi-hat")
        drum2ImageView.image = UIImage(named: "drum2_off")

        // 初始化播放器
        drumURL = Bundle.main.url(forResource: "drum", withExtension: "wav")
        kickDrumURL = Bundle.main.url(forResource: "kickDrum", withExtension: "wav")
        hiHatURL = Bundle.main.url(forResource: "hiHat", withExtension: "wav")
        drum2URL = Bundle.main.url(forResource: "drum2", withExtension: "wav")


        // 初始化每个设备状态
        for name in deviceNames {
            imuDevices[name] = IMUDevice()
        }

        // 映射设备名到图像
        drumImageViews = [
            "HaptiDrum_Hand_L": drum2ImageView,
            "HaptiDrum_Hand_R": drumImageView,
            "HaptiDrum_Foot_L": hihatImageView,
            "HaptiDrum_Foot_R": kickDrumImageView
        ]
        
        // 启用用户交互并添加点击手势
        for (deviceName, imageView) in drumImageViews {
            imageView.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleDrumTap(_:)))
            imageView.addGestureRecognizer(tap)
            imageView.tag = deviceNames.firstIndex(of: deviceName) ?? -1  // 用 tag 区分哪个图片
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupBLEHandler()
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        BLEManager.shared.setDataHandler(nil)
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


    
    @objc func handleDrumTap(_ sender: UITapGestureRecognizer) {
        guard let tappedView = sender.view else { return }

        let index = tappedView.tag
        guard index >= 0 && index < deviceNames.count else { return }

        let deviceName = deviceNames[index]
        print("[\(deviceName)] 🖱️ Image tapped")

        // 播放对应音效
        let soundMap: [String: URL?] = [
            "HaptiDrum_Hand_R": drumURL,
            "HaptiDrum_Hand_L": drum2URL,
            "HaptiDrum_Foot_R": kickDrumURL,
            "HaptiDrum_Foot_L": hiHatURL
        ]

        if let soundURL = soundMap[deviceName] ?? nil {
            playSound(from: soundURL)
        }
    }
    
    private func setupBLEHandler() {
        BLEManager.shared.setDataHandler { [weak self] peripheral, data in
            guard let self = self else { return }
            guard let name = peripheral.name, self.deviceNames.contains(name) else { return }

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

            device.gx = gx
            device.gy = gy
            device.gz = gz

            let isHand = name.contains("Hand")
            let inRange: Bool = isHand
                ? abs(adjPitch) < 20 && abs(adjRoll) < 20 && abs(adjYaw) < 20
                : abs(adjPitch) < 20 && abs(adjRoll) < 20

            if inRange && !device.inHitZone {
                print("[\(name)] 🥁 Drum Hit Detected!")
                device.inHitZone = true

                if let peripheral = BLEManager.shared.connectedPeripherals.first(where: { $0.name == name }) {
                    let playCommand = BLECommand(type: "PLAY", payload: nil)
                    BLEManager.shared.sendCommand(playCommand, to: peripheral)
                    print("[\(name)] 📡 Sent PLAY to peripheral")
                }

                let soundMap: [String: URL?] = [
                    "HaptiDrum_Hand_R": self.drumURL,
                    "HaptiDrum_Hand_L": self.drum2URL,
                    "HaptiDrum_Foot_R": self.kickDrumURL,
                    "HaptiDrum_Foot_L": self.hiHatURL
                ]

                if let soundURL = soundMap[name] ?? nil {
                    self.playSound(from: soundURL)
                }

                if let imageView = self.drumImageViews[name] {
                    DispatchQueue.main.async {
                        switch name {
                        case "HaptiDrum_Foot_R":
                            imageView.image = UIImage(named: "kickDrum_on")
                        case "HaptiDrum_Hand_R":
                            imageView.image = UIImage(named: "drum_on")
                        case "HaptiDrum_Hand_L":
                            imageView.image = UIImage(named: "drum2_on")
                        default:
                            break
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        switch name {
                        case "HaptiDrum_Foot_R":
                            imageView.image = UIImage(named: "kickDrum_off")
                        case "HaptiDrum_Hand_R":
                            imageView.image = UIImage(named: "drum_off")
                        case "HaptiDrum_Hand_L":
                            imageView.image = UIImage(named: "drum2_off")
                        default:
                            break
                        }
                    }
                }

            } else if !inRange {
                device.inHitZone = false
            }

            self.imuDevices[name] = device
        }
    }


    
}

// 平均值扩展
extension Array where Element == Double {
    var average: Double {
        return self.isEmpty ? 0 : self.reduce(0, +) / Double(self.count)
    }
}

