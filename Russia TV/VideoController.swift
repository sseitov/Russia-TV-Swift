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

class VideoController: UIViewController, UIWebViewDelegate {
    
    @IBOutlet weak var webView: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("НАВАЛЬНЫЙ LIVE")
        refresh()
    }
    
    @IBAction func refresh() {
        if let url = URL(string: "https://www.youtube.com/channel/UCgxTPTFbIbCWfTR9I2-5SeQ/videos") {
            webView.loadRequest(URLRequest(url: url))
        }
    }
    
    func goBack() {
        webView.goBack()
    }
    
    // MARK: - WebView delegate
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        SVProgressHUD.show()
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        SVProgressHUD.dismiss()
        if webView.canGoBack {
            let btn = UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: self, action: #selector(self.goBack))
            btn.tintColor = UIColor.white
            navigationItem.setLeftBarButton(btn, animated: true)
        } else {
            navigationItem.setLeftBarButton(nil, animated: true)
        }
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if let videos = HCYoutubeParser.h264videos(withYoutubeURL: request.url),
            let media = videos["medium"] as? String,
            let url = URL(string: media)
        {
            let video = AVPlayerViewController()
            present(video, animated: true, completion: {
                video.player = AVPlayer(url: url)
                video.player?.play()
            })
            return false
        } else {
            return true
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
}
