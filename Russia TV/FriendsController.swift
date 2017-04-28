//
//  FriendsController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import MessageUI
import GoogleSignIn

class FriendsController: UITableViewController, GIDSignInDelegate {

    private var friends:[User] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(NSLocalizedString("friends", comment: ""))
        setupBackButton()
        
        if let provider = FIRAuth.auth()!.currentUser!.providerData.first {
            if provider.providerID == "google.com" {
                GIDSignIn.sharedInstance().delegate = self
                GIDSignIn.sharedInstance().signInSilently()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        friends = Model.shared.getFriends()
        tableView.reloadData()
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if user != nil {
            let btn = UIBarButtonItem(image: UIImage(named: "invite"), style: .plain, target: self, action: #selector(self.sendInvite))
            btn.tintColor = UIColor.white
            navigationItem.setRightBarButton(btn, animated: true)
        }
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
    
    func sendInvite() {
        if let invite = FIRInvites.inviteDialog() {
            invite.setInviteDelegate(self)
            var message = NSLocalizedString("invite", comment: "")
            message += "\n---------------------\n \(currentUser()!.name!)"
            if currentUser()!.email != nil {
                message += "\n \(currentUser()!.email!)"
            }
            invite.setMessage(message)
            invite.setTitle(NSLocalizedString("inviteTitle", comment: ""))
            invite.setDeepLink(deepLink)
            invite.setCallToActionText("Install")
            invite.open()
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count + 1
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row > 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "member", for: indexPath) as! MemberCell
            cell.friend = friends[indexPath.row-1]
            return cell
        } else {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.imageView?.image = UIImage(named: "friends")
            cell.contentView.backgroundColor = UIColor.groupTableViewBackground
            cell.detailTextLabel?.text = NSLocalizedString("addToFriends", comment: "addToFriends")
            cell.detailTextLabel?.font = UIFont.condensedFont()
            cell.detailTextLabel?.textColor = UIColor.mainColor()
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            performSegue(withIdentifier: "members", sender: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            let user = friends[indexPath.row - 1]
            friends.remove(at: indexPath.row - 1)
            Model.shared.deleteUser(user.uid!)
            tableView.deleteRows(at: [indexPath], with: .top)
            tableView.endUpdates()
        }
    }
}

extension FriendsController : FIRInviteDelegate {
    
    func inviteFinished(withInvitations invitationIds: [String], error: Error?) {
        if let error = error {
            if error.localizedDescription != "Canceled by User" {
                let message = String(format: NSLocalizedString("inviteError", comment: ""), error.localizedDescription)
                showMessage(message, messageType: .error)
            }
        } else {
            let message = String(format: NSLocalizedString("inviteResult", comment: ""), invitationIds.count)
            showMessage(message, messageType: .information)
        }
    }
}

extension FriendsController : FBSDKAppInviteDialogDelegate {
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didCompleteWithResults results: [AnyHashable : Any]!) {
        print(results)
    }
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didFailWithError error: Error!) {
        print(error)
    }
   
}
