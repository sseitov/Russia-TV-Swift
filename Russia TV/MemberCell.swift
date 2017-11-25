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
    @IBOutlet weak var email: UILabel!
    
    var friend:AppUser? {
        didSet {
            name.text = friend!.name
            email.text = friend!.email
            let url = URL(string: friend!.avatar!)
            SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: nil, completed: {image, _, _, _ in
                if image != nil {
                    self.avatar.image = image!.withSize(self.avatar.frame.size).inCircle()
                } else {
                    self.avatar.image = UIImage(named:"user")
                }
            })
        }
    }
    
    var member:[String:Any]? {
        didSet {
            if member != nil {
                name.text = member!["name"] as? String
                email.text = member!["email"] as? String
                if let picture = member!["avatar"] as? String {
                    SDWebImageDownloader.shared().downloadImage(with: URL(string: picture), options: [], progress: nil, completed: {image, _, _, _ in
                        if image != nil {
                            self.avatar.image = image!.withSize(self.avatar.frame.size).inCircle()
                        } else {
                            self.avatar.image = UIImage(named:"user")
                        }
                    })
                }
            }
        }
    }
}
