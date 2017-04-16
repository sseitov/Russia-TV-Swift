//
//  VideoController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 16.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class TimeLine: UIView {
    
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var indicator:UILabel!
    @IBOutlet weak var button:UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        slider.setThumbImage(UIImage(named: "thumb"), for: .normal)
        slider.value = 0
    }
    
    func setupButton(_ target:Any?, image:UIImage?, selector:Selector) {
        button.setImage(image, for: .normal)
        button.addTarget(target, action: selector, for: .touchUpInside)
    }
}

class VideoController: UIViewController, PlayerDelegate {

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var timeLine: TimeLine!
    @IBOutlet weak var controlPosition: NSLayoutConstraint!
    
    var isFullScreen = false
    var target:[String:Any]?
    
    private var videoPlayer:VideoView?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackButton()
        if let name = target!["title"] as? String {
            let comps = name.components(separatedBy: ".")
            setupTitle(comps[0])
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.fullScreen))
        videoView.addGestureRecognizer(tap)
        
        videoPlayer = VideoView(frame: videoView.bounds)
        videoPlayer!.autoresizingMask = UIViewAutoresizing.flexibleHeight.union(.flexibleWidth)
        videoPlayer!.contentMode = .scaleAspectFit
        videoPlayer!.delegate = self
        videoPlayer!.url = target!["url"] as? URL
        
        timeLine.slider.addTarget(videoPlayer, action: #selector(VideoView.sliderBeganTracking(_:)), for: .touchDown)
        let events = UIControlEvents.touchUpInside.union(UIControlEvents.touchUpOutside)
        timeLine.slider.addTarget(videoPlayer, action: #selector(VideoView.sliderEndedTracking(_:)), for: events)
        videoView.addSubview(videoPlayer!)
    }

    func fullScreen() {
        isFullScreen = !isFullScreen
        self.navigationController?.setNavigationBarHidden(self.isFullScreen, animated: true)
        controlPosition.constant = isFullScreen ? -60 : 0
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
        })
    }
    
    override func goBack() {
        SVProgressHUD.dismiss()
        videoPlayer?.pause()
        videoPlayer!.delegate = nil
        super.goBack()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        videoPlayer?.start()
    }
    
    // MARK: - Video player
    
    func play() {
        timeLine.setupButton(self, image: UIImage(named: "pause"), selector: #selector(self.pause))
        videoPlayer!.play()
    }
    
    func pause() {
        timeLine.setupButton(self, image: UIImage(named: "play"), selector: #selector(self.play))
        videoPlayer!.pause()
    }
    
    func prepareForStart() {
        SVProgressHUD.show(withStatus: "Load...")
    }
    
    func playerStarted() {
        SVProgressHUD.dismiss()
        play()
    }
    
    private func timeToString(_ time:Double) -> String {
        let hour = Int(time) / 3600
        let min = hour == 0 ? Int(time) / 60 : (Int(time) % 3600) / 60
        let sec = Int(time) % 60
        if hour == 0 {
            return String(format: "%d:%.2d", min, sec)
        } else {
            return String(format: "%d.%.2d:%.2d", hour, min, sec)
        }
    }

    func playSetPosition(_ elapsed:Double, duration:Double) {
        let position = elapsed/duration
        timeLine.slider.value = Float(position)
        timeLine.indicator.text = "\(timeToString(elapsed)) / \(timeToString(duration))"
    }
    
    func playerFinished() {
        timeLine.slider.value = 0
        videoPlayer!.sliderEndedTracking(timeLine.slider)
        timeLine.setupButton(self, image: UIImage(named: "play"), selector: #selector(self.play))
    }

}
