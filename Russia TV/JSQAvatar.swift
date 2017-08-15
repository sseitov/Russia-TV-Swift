//
//  JSQAvatar.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 19.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

let refreshAvatarNotification = Notification.Name("REFRESH_USER")

class JSQAvatar : NSObject, JSQMessageAvatarImageDataSource {
    
    var userImage:UIImage?
    var user:AppUser?
    var indexPath:IndexPath?
    
    init(_ userID:String, indexPath: IndexPath) {
        super.init()
        self.indexPath = indexPath
        self.user = Model.shared.getUser(userID)
        if self.user != nil {
            userImage = SDImageCache.shared().imageFromDiskCache(forKey: self.user!.avatar!)
            if userImage == nil {
                let url = URL(string: self.user!.avatar!)
                SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: nil, completed: { image, _, _, _ in
                    if image != nil {
                        self.userImage = image!.inCircle()
                        SDImageCache.shared().store(self.userImage, forKey: self.user!.avatar!, completion: {
                            NotificationCenter.default.post(name: refreshAvatarNotification, object: self.indexPath)
                        })
                    }
                })
            }
        } else {
            userImage = UIImage(named: "user")
        }
    }
    
    func avatarImage() -> UIImage! {
        return userImage
    }
    
    func avatarHighlightedImage() -> UIImage! {
        return userImage
    }
    
    func avatarPlaceholderImage() -> UIImage! {
        return UIImage(named: "logo")?.inCircle()
    }
}
