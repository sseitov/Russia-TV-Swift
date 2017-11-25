//
//  VideoView.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 16.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import AVFoundation

protocol PlayerDelegate {
    func prepareForStart()
    func playerStarted()
    func playSetPosition(_ elapsed:Double, duration:Double)
    func playerFinished()
    func playerError(_ error:NSError?)
}

class VideoView: UIView {
    
    var delegate:PlayerDelegate?    
    var url:URL?
    
    fileprivate var avPlayer:AVPlayer?
    fileprivate var avPlayerLayer: AVPlayerLayer?
    fileprivate var playerItem:AVPlayerItem?
    fileprivate weak var timeObserver: AnyObject?
    
    fileprivate var playerRateBeforeSeek: Float = 0
    fileprivate var finished:Bool = false
    
    // MARK: - Live cicle
    
    func destroy() {
        if avPlayer != nil {
            avPlayerLayer!.player = nil
            avPlayer!.pause()
            avPlayer!.removeTimeObserver(timeObserver!)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if avPlayerLayer != nil {
            avPlayerLayer!.frame = self.bounds
        }
    }
    
    // MARK: - Video commands
    
    @objc func sliderBeganTracking(_ slider: UISlider!) {
        playerRateBeforeSeek = avPlayer!.rate
        avPlayer!.pause()
    }
    
    @objc func sliderEndedTracking(_ slider: UISlider!) {
        let videoDuration = CMTimeGetSeconds(avPlayer!.currentItem!.duration)
        let elapsedTime: Float64 = videoDuration * Float64(slider.value)
        let time = CMTime(seconds: Double(elapsedTime), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        avPlayer!.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { completed in
            if (self.playerRateBeforeSeek > 0) {
                if !self.finished {
                    self.avPlayer!.play()
                    self.avPlayer!.rate = self.playerRateBeforeSeek
                } else {
                    self.finished = false
                }
            }
        })
    }
    
    @objc func itemDidFinishPlaying(_ notification:Notification) {
        finished = true
        delegate!.playerFinished()
    }
    
    func start() {
        if self.url == nil {
            print("no url error")
            return
        }
        
        avPlayer = AVPlayer()
        avPlayerLayer = AVPlayerLayer(player: avPlayer)
        layer.insertSublayer(avPlayerLayer!, at: 0)
        
        playerItem = AVPlayerItem(url: url!)
        avPlayer!.replaceCurrentItem(with: playerItem!)
        
        let timeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = avPlayer!.addPeriodicTimeObserver(forInterval: timeInterval, queue: nil) { elapsedTime in
            let duration = CMTimeGetSeconds(self.avPlayer!.currentItem!.duration)
            if duration.isFinite {
                let elapsedTimeSec = CMTimeGetSeconds(elapsedTime)
                if self.delegate != nil {
                    self.delegate!.playSetPosition(elapsedTimeSec, duration: round(duration))
                }
            }
            } as AnyObject!
        
        NotificationCenter.default.addObserver(self, selector: #selector(VideoView.itemDidFinishPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        delegate!.prepareForStart()
        
        playerItem!.asset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: {
            var error: NSError? = nil
            let status = self.playerItem!.asset.statusOfValue(forKey: "playable", error: &error)
            switch status {
            case .loaded:
                DispatchQueue.main.async {
                    self.delegate!.playerStarted()
                }
            case .failed:
                self.delegate?.playerError(error)
            default:
                break
            }
        })
    }
    
    func play() {
        if avPlayer != nil {
            avPlayer!.play()
        }
    }
    
    func pause() {
        if avPlayer != nil {
            avPlayer!.pause()
        }
    }
}
