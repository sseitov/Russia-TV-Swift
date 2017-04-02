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

enum MessageType {
    case error, success, information
}

class VideoController: AVPlayerViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }
    
    func refresh() {
        if let url = URL(string: "https://www.youtube.com/channel/UCgxTPTFbIbCWfTR9I2-5SeQ/videos") {
            SVProgressHUD.show()
            DispatchQueue.global().async {
                if let pageData = try? Data(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.parseHtml(pageData)
                    }
                } else {
                    self.showError()
                }
            }
        } else {
            showError()
        }
    }
    
    func showError() {
        SVProgressHUD.dismiss()
        showMessage("Can not load content.", messageType: .error)
    }
    
    func parseHtml(_ data:Data) {
        let scrapper = HtmlScrapper(data: data)
        if let items = scrapper.items() {
            if items.count > 0 {
                let urlString = "https://www.youtube.com/watch?v=\(items[0])"
                if let topUrl = URL(string: urlString) {
                    YouTubeParser.video(withYoutubeURL: topUrl, complete: { media, error in
                        if media != nil, let url = URL(string: media!) {
                            SVProgressHUD.dismiss()
                            self.player = AVPlayer(url: url)
                            self.player?.seek(to: CMTimeMakeWithSeconds(10, 1))
                            self.player?.play()
                        } else {
                            self.showError()
                        }
                    })
                } else {
                    showError()
                }
            } else {
                showError()
            }
        } else {
            showError()
        }
    }
}


extension UIViewController {
    
    func setupTitle(_ text:String) {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        label.textAlignment = .center
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15)
        label.text = text
        label.textColor = UIColor.white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        navigationItem.titleView = label
    }
    
    func showMessage(_ message:String, messageType:MessageType, messageHandler: (() -> ())? = nil) {
        var title:String = ""
        switch messageType {
        case .success:
            title = "Success"
        case .information:
            title = "Information"
        default:
            title = "Error"
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            if messageHandler != nil {
                messageHandler!()
            }
        }))
        present(alert, animated: true, completion: nil)
    }
}
