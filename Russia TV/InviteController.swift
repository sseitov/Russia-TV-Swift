//
//  InviteController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import MessageUI

/*
Apple ID Автоматически созданный ID приложения.
929186395
 
https://itunes.apple.com/us/app/cactus/id929186395?l=ru&ls=1&mt=8
*/

class InviteController: UITableViewController, MFMailComposeViewControllerDelegate {

    private var friends:[User] = []
    private var allFriends:[Any] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(NSLocalizedString("members", comment: ""))
        setupBackButton()
        
        friends = Model.shared.getFriends()
        NotificationCenter.default.addObserver(self, selector: #selector(self.newUserNotify(_:)), name: newUserNotification, object: nil)
        let params = ["fields" : "id,name,picture.width(100).height(100)"]
        let request = FBSDKGraphRequest(graphPath: "me/taggable_friends?limit=100", parameters: params)
        request!.start(completionHandler: { _, result, error in
            if let data = result as? [String:Any], let friends = data["data"] as? [Any] {
                for friend in friends {
                    if let friendData = friend as? [String:Any], let name = friendData["name"] as? String {
                        if Model.shared.userByName(name) == nil {
                            self.allFriends.append(friend)
                        }
                    }
                }
                self.tableView.reloadData()
            }
        })
    }

    @IBAction func invite(_ sender: Any) {
        if MFMailComposeViewController.canSendMail() {
            let alert = EmailInput.getEmail(cancelHandler: {}, acceptHandler: { email in
                let mailController = MFMailComposeViewController()
                mailController.mailComposeDelegate = self
                mailController.setToRecipients([email])
                mailController.setSubject(NSLocalizedString("inviteTitle", comment: ""))
                mailController.setMessageBody(NSLocalizedString("invite", comment: ""), isHTML: true)
                self.present(mailController, animated: true, completion: nil)
            })
            alert?.show()
        }
/*
        let invite = FBSDKAppInviteContent()
        invite.appLinkURL = URL(string: "https://fb.me/407956749561194")
        FBSDKAppInviteDialog.show(from: self, with: invite, delegate: self)
*/
    }
 
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: {
            if error != nil {
                self.showMessage(String.localizedStringWithFormat( NSLocalizedString("inviteError", comment: "") , error!.localizedDescription), messageType: .error)
            } else {
                if result == .sent {
                    self.showMessage(NSLocalizedString("inviteResult", comment: ""), messageType: .information)
                }
            }
        })
    }
    
    func newUserNotify(_ notify:Notification) {
        if let user = notify.object as? User {
            self.tableView.beginUpdates()
            let indexPath = IndexPath(row: self.friends.count, section: 0)
            self.friends.append(user)
            self.tableView.insertRows(at: [indexPath], with: .bottom)
            self.tableView.endUpdates()
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? friends.count : allFriends.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? NSLocalizedString("my friends with cactus", comment: "") : NSLocalizedString("other my friends", comment: "")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "member", for: indexPath) as! MemberCell
        if indexPath.section == 0 {
            cell.user = friends[indexPath.row]
        } else {
            cell.friend = allFriends[indexPath.row] as? [String:Any]
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            let user = friends[indexPath.row]
            Model.shared.deleteUser(user.uid!)
            friends.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .top)
            tableView.endUpdates()
        }
    }
}
/*
extension InviteController : FBSDKAppInviteDialogDelegate {
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didCompleteWithResults results: [AnyHashable : Any]!) {
        print("didCompleteWithResults \(results)")
    }
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didFailWithError error: Error!) {
        print("didFailWithError \(error)")
    }
}
*/
