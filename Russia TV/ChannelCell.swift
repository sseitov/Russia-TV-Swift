//
//  ChannelCell.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 03.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

func IS_PAD() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

class ChannelCell: UITableViewCell {

    @IBOutlet weak var thumb: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var meta: UILabel!
    
    var channel:Channel? {
        didSet {
            if IS_PAD() {
                title.font = UIFont.mainFont(17)
                meta.font = UIFont.condensedFont(17)
            } else {
                title.font = UIFont.mainFont(13)
                meta.font = UIFont.condensedFont(13)
            }
            title.text = channel!.channelTitle
            meta.text = channel!.channelMeta
            thumb.sd_setImage(with: channel!.channelThumb, completed: { image, error, _, _ in
                if error != nil {
                    print(error!.localizedDescription)
                }
            })
        }
    }
}
