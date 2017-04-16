//
//  ChannelsController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 24.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

enum MessageType {
    case error, success, information
}

class Channel : NSObject {
    var channelURL:URL?
    var channelThumb:URL?
    var channelTitle:String?
    var channelMeta:String?
}

class ChannelsController: UITableViewController {
    
    private var channels:[Channel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("НАВАЛЬНЫЙ LIVE")
        refreshTable()
    }
    
    @IBAction func refresh(_ sender: UIRefreshControl) {
        refreshContent({ success in
            sender.endRefreshing()
            self.tableView.reloadData()
            if !success {
                self.showMessage("Can not load content.", messageType: .error)
            }
        })
    }
    
    func refreshTable() {
        SVProgressHUD.show(withStatus: "Refresh...")
        refreshContent({ success in
            SVProgressHUD.dismiss()
            self.tableView.reloadData()
            if !success {
                self.showMessage("Can not load content.", messageType: .error)
            }
        })
    }
    
    func refreshContent(_ success: @escaping(Bool) -> ()) {
        if let url = URL(string: "https://www.youtube.com/channel/UCgxTPTFbIbCWfTR9I2-5SeQ/videos") {
            DispatchQueue.global().async {
                if let pageData = try? Data(contentsOf: url) {
                    DispatchQueue.main.async {
                        success(self.parseHtml(pageData))
                    }
                } else {
                    success(false)
                }
            }
        } else {
            success(false)
        }
    }
    
    func parseHtml(_ data:Data) -> Bool {
        let scrapper = HtmlScrapper(data: data)
        channels = scrapper.videoChannels()
        return channels.count > 0
    }
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channels.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "channel", for: indexPath) as! ChannelCell
        cell.channel = channels[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let channel = channels[indexPath.row]
        SVProgressHUD.show(withStatus: "Load...")
        YouTubeParser.video(withYoutubeURL: channel.channelURL, complete: { media, error in
            if media != nil, let url = URL(string: media!) {
                SVProgressHUD.dismiss()
                let target:[String:Any] = ["title" : channel.channelTitle!, "url" : url]
                self.performSegue(withIdentifier: "video", sender: target)
/*
                let video = AVPlayerViewController()
                self.present(video, animated: true, completion: {
                    video.player = AVPlayer(url: url)
                    video.player?.seek(to: CMTimeMakeWithSeconds(10, 1))
                    video.player?.play()
                })
 */
            } else {
                self.showMessage("Can not load content.", messageType: .error)
            }
        })
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "video" {
            let next = segue.destination as! VideoController
            next.target = sender as? [String:Any]
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
    
    func setupBackButton() {
        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(self.goBack)
    }
    
    func goBack() {
        _ = self.navigationController!.popViewController(animated: true)
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
