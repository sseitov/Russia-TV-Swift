//
//  VideoController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 24.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class VideoController: AVPlayerViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        start()
    }
    
    func start() {
        let youTubeUrl = URL(string: "https://www.youtube.com/watch?v=Tv63uuNoQC4")
        if let videos = HCYoutubeParser.h264videos(withYoutubeURL: youTubeUrl), let media = videos["medium"] as? String, let url = URL(string: media) {
            self.player = AVPlayer(url: url)
//            let startTime = CMTimeMakeWithSeconds(120, 1)
//            self.player?.seek(to: startTime)
            self.player?.play()
        }
    }
}
