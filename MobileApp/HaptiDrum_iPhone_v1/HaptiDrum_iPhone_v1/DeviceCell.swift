//
//  DeviceCell.swift
//  HaptiDrum_iPhone_v1
//
//  Created by Hongrui Wu  on 4/25/25.
//

import UIKit

class DeviceCell: UITableViewCell {

    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var findButton: UIButton!
    @IBOutlet weak var connectButton: UIButton!
    
    
    var onFindTapped: (() -> Void)?
    var onConnectTapped: (() -> Void)?
    
    
    override func awakeFromNib() {
        super.awakeFromNib()

    }

    
    @IBAction func findButtonTapped(_ sender: UIButton) {
        onFindTapped?()
    }

    @IBAction func connectButtonTapped(_ sender: UIButton) {
        onConnectTapped?()
    }
}
