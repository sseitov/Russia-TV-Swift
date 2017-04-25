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
import GoogleSignIn

class MembersController: UITableViewController, FIRInviteDelegate, GIDSignInDelegate {

    private var friends:[User] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(NSLocalizedString("members", comment: ""))
        setupBackButton()
        
        friends = Model.shared.getFriends()
        let providers = FIRAuth.auth()!.currentUser!.providerData
        for provider in providers {
            print(provider.providerID)
            if provider.providerID == "google.com" {
                GIDSignIn.sharedInstance().delegate = self
                GIDSignIn.sharedInstance().signInSilently()
            }
        }

        print(GIDSignIn.sharedInstance().currentUser)
        
    }

    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if user != nil {
            let btn = UIBarButtonItem(image: UIImage(named: "add"), style: .plain, target: self, action: #selector(self.sendInvite))
            btn.tintColor = UIColor.white
            self.navigationItem.setRightBarButton(btn, animated: true)
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
            message += "\n----\n \(currentUser()!.name!)"
            invite.setMessage(message)
            invite.setTitle(NSLocalizedString("inviteTitle", comment: ""))
            invite.setDeepLink("https://fb.me/407956749561194")
            invite.setCallToActionText("Install")
            invite.open()
        }
    }
    
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
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("friends", comment: "")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "member", for: indexPath) as! MemberCell
        cell.user = friends[indexPath.row]
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
