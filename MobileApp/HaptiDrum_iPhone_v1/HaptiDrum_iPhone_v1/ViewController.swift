//
//  ViewController.swift
//  HaptiDrum_iPhone_v1
//
//  Created by Hongrui Wu  on 4/24/25.
//

import UIKit
import CoreBluetooth  // BLE connection


class ViewController: UIViewController,  UITableViewDataSource, UITableViewDelegate {

//    let bleManager = BLEManager()
    let bleManager = BLEManager.shared
    
    
    // Button Initializer
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        bleManager.onPeripheralDiscovered = { [weak self] peripheral in
            self?.tableView.reloadData()
        }

        bleManager.onPeripheralConnected = { [weak self] peripheral in
            self?.tableView.reloadData()
        }

        tableView.dataSource = self
        tableView.delegate = self
    }
    

    
    @IBAction func scanButtonTapped(_ sender: UIButton) {
        bleManager.scan()
    }
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showDrumView", sender: self)
    }

    
    
    // Table view
    @IBOutlet weak var tableView: UITableView!

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bleManager.discoveredPeripherals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as? DeviceCell else {
            return UITableViewCell()
        }
        let peripheral = bleManager.discoveredPeripherals[indexPath.row]
        let name = peripheral.name ?? "Unknown"
        cell.nameLabel.text = name
        cell.connectButton.setTitle(bleManager.getState(for: peripheral) ? "Connected" : "Connect", for: .normal)
        
        cell.onFindTapped = { [weak self] in
            self?.bleManager.sendCommand(BLECommand(type: "FIND", payload: nil), to: peripheral)
        }

        cell.onConnectTapped = { [weak self] in
            self?.bleManager.sendCommand(BLECommand(type: "CONNECT", payload: nil), to: peripheral)
        }

        return cell
    }
}
