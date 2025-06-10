//
//  BLEManager.swift
//  HaptiDrum_iPhone_v1
//
//  Created by Hongrui Wu  on 5/1/25.
//

import Foundation
import CoreBluetooth

struct BLECommand {
    let type: String
    let payload: [String: String]?

    func toData() -> Data? {
        if let payload = payload {
            var dict = payload
            dict["type"] = type
            return try? JSONSerialization.data(withJSONObject: dict)
        } else {
            return type.data(using: .utf8)
        }
    }
}

struct PeripheralCommandState {
    var pendingCommand: BLECommand?
    var characteristic: CBCharacteristic?
}

class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // Singleton instance
    static let shared = BLEManager()
    
    
    private var bleBufferMap: [UUID: String] = [:]

    

    // MARK: - Public Properties
    var onPeripheralDiscovered: ((CBPeripheral) -> Void)?
    var onPeripheralConnected: ((CBPeripheral) -> Void)?

    var discoveredPeripherals: [CBPeripheral] = []
    
    // Called when a JSON message is received via BLE notify
        var onDataReceived: ((CBPeripheral, [String: Any]) -> Void)?

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private let serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
    private let characteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
    private var peripheralCommandMap: [String: PeripheralCommandState] = [:]

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public API

    func scan() {
        discoveredPeripherals.removeAll()
        peripheralCommandMap.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("BLE scanning...")
    }

    func sendCommand(_ command: BLECommand, to peripheral: CBPeripheral) {
        guard let name = peripheral.name else { return }

        if peripheral.delegate == nil {
            peripheral.delegate = self
        }

        if peripheral.state == .connected {
            if let char = peripheralCommandMap[name]?.characteristic,
               let data = command.toData() {
                peripheral.writeValue(data, for: char, type: .withResponse)
                print("Sent command directly: \(command.type) to \(name)")
            } else {
                var state = peripheralCommandMap[name] ?? PeripheralCommandState()
                state.pendingCommand = command
                peripheralCommandMap[name] = state
                peripheral.discoverServices([CBUUID(string: serviceUUID)])
            }
        } else {
            var state = peripheralCommandMap[name] ?? PeripheralCommandState()
            state.pendingCommand = command
            peripheralCommandMap[name] = state
            centralManager.connect(peripheral, options: nil)
        }
    }

    func getState(for peripheral: CBPeripheral) -> Bool {
        guard let name = peripheral.name else { return false }
        return peripheralCommandMap[name]?.characteristic != nil
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("BLE Ready")
        } else {
            print("Bluetooth not ready: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.hasPrefix("HaptiDrum"),
           !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
            onPeripheralDiscovered?(peripheral)
        }
    }
    
    // 保存所有连接成功的 peripheral
    private(set) var connectedPeripherals: [CBPeripheral] = []

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        
        // 去重添加
        if !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            connectedPeripherals.append(peripheral)
        }

        onPeripheralConnected?(peripheral)
        peripheral.discoverServices([CBUUID(string: serviceUUID)])
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([CBUUID(string: characteristicUUID)], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics,
              let name = peripheral.name else { return }

        var state = peripheralCommandMap[name] ?? PeripheralCommandState()

        for char in characteristics {
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
                print("Subscribed to notifications from \(name)")
            }

            if char.properties.contains(.write) {
                state.characteristic = char
                if let command = state.pendingCommand,
                   let data = command.toData() {
                    peripheral.writeValue(data, for: char, type: .withResponse)
                    print("Sent cached command via discovery: \(command.type) to \(name)")
                    state.pendingCommand = nil
                }
                peripheralCommandMap[name] = state
            }
        }
    }


    
    // MARK: - Receiving Notification Data

    /// Handles incoming BLE notification data from the peripheral.
    /// Automatically called when a characteristic with `.notify` updates.
//    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
//        guard let data = characteristic.value else {
//            print("Received empty data from \(peripheral.name ?? "Unknown")")
//            return
//        }
//
//        // Try to decode data as UTF-8 string
//        if let message = String(data: data, encoding: .utf8) {
//            print("Received from \(peripheral.name ?? "Unknown"): \(message)")
//
//            // Try to parse as JSON
//            if let jsonData = message.data(using: .utf8),
//               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
//               let dictionary = jsonObject as? [String: Any] {
//                // Parsed successfully
//                onDataReceived?(peripheral, dictionary)
//            } else {
//                print("Failed to parse JSON from message.")
//            }
//        } else {
//            print("Unable to decode data from \(peripheral.name ?? "Unknown")")
//        }
//    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("🔔 got BLE update from \(peripheral.name ?? "Unknown")")

        guard let data = characteristic.value,
              let string = String(data: data, encoding: .utf8) else {
            print("❌ Unable to decode data from \(peripheral.name ?? "Unknown")")
            return
        }

        // Append to buffer
        bleBufferMap[peripheral.identifier, default: ""] += string
        var buffer = bleBufferMap[peripheral.identifier] ?? ""

        while let startIndex = buffer.firstIndex(of: "{") {
            var braceCount = 0
            var endIndex: String.Index? = nil

            for index in buffer[startIndex...].indices {
                let char = buffer[index]
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        endIndex = index
                        break
                    }
                }
            }

            // 没有找到完整的一对花括号，等待下一次补全
            guard let endIndex = endIndex else { break }

            let jsonSubstring = buffer[startIndex...endIndex]
            let jsonString = String(jsonSubstring)

            // 更新 buffer（去掉已解析部分）
            buffer = String(buffer[buffer.index(after: endIndex)...])
            bleBufferMap[peripheral.identifier] = buffer

            // 尝试解析 JSON
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("❌ Failed to convert to Data: \(jsonString)")
                continue
            }

            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    print("✅ \(peripheral.name ?? "Unknown") : \(jsonObject)")
                    onDataReceived?(peripheral, jsonObject)
                } else {
                    print("⚠️ JSON decoded but not a dictionary: \(jsonString)")
                }
            } catch {
                print("❌ Failed to parse JSON: \(jsonString)")
            }

        }

        // 最后更新 buffer（等待下一次补全）
        bleBufferMap[peripheral.identifier] = buffer
    }


    func setDataHandler(_ handler: ((CBPeripheral, [String: Any]) -> Void)?) {
        self.onDataReceived = handler
    }


    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("📣 Notify updated: \(characteristic.uuid), isNotifying: \(characteristic.isNotifying)")
    }

}
