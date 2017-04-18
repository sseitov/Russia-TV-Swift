//
//  MemberCell.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class MemberCell: UITableViewCell {

    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var name: UILabel!
    
    var user:User? {
        didSet {
            name.text = user!.name
            let url = URL(string: user!.avatar!)
            SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: nil, completed: {image, _, _, _ in
                if image != nil {
                    self.avatar.image = image!.inCircle()
                }
            })
        }
    }
}
