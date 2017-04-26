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

class MembersController: UIViewController, UITableViewDelegate, UITableViewDataSource, GIDSignInDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var inviteBarHeight: NSLayoutConstraint!

    private var friends:[User] = []
    private var members:[Any] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(NSLocalizedString("members", comment: ""))
        setupBackButton()
        
        friends = Model.shared.getFriends()
        tableView.isEditing = true
        inviteBarHeight.constant = 0
        refresh()
    }
    
    @IBAction func refresh() {
        SVProgressHUD.show(withStatus: "Refresh...")
        Model.shared.members({ members in
            SVProgressHUD.dismiss()
            self.members = members
            self.tableView.reloadData()
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let provider = FIRAuth.auth()!.currentUser!.providerData.first {
            if provider.providerID == "google.com" {
                GIDSignIn.sharedInstance().delegate = self
                GIDSignIn.sharedInstance().signInSilently()
            }
        }
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if user != nil {
            self.view.layoutIfNeeded()
            inviteBarHeight.constant = 44
            UIView.animate(withDuration: 0.5, animations: {
                self.view.layoutIfNeeded()
            })
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
    
    @IBAction func sendInvite() {
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

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? friends.count : members.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? NSLocalizedString("friends", comment: "") : NSLocalizedString("not_friends", comment: "")
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return indexPath.section == 0 ? .delete : .insert
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "member", for: indexPath) as! MemberCell
        if indexPath.section == 0 {
            cell.friend = friends[indexPath.row]
        } else {
            cell.member = members[indexPath.row] as? [String:Any]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let user = friends[indexPath.row]
            
            tableView.beginUpdates()
            
            var member = ["uid" : user.uid!]
            if user.name != nil {
                member["name"] = user.name!
            }
            if user.email != nil {
                member["email"] = user.email!
            }
            if user.avatar != nil {
                member["avatar"] = user.avatar!
            }
            let insertPath = IndexPath(row: members.count, section: 1)
            members.append(member)
            tableView.insertRows(at: [insertPath], with: .bottom)
            tableView.endUpdates()
            
            tableView.beginUpdates()
            Model.shared.deleteUser(user.uid!)
            friends.remove(at: indexPath.row)
            let deletePath = indexPath
            tableView.deleteRows(at: [deletePath], with: .top)
            tableView.endUpdates()
        } else if editingStyle == .insert {
            if let member = members[indexPath.row] as? [String:Any] {
                SVProgressHUD.show(withStatus: "Add...")
                Model.shared.addUser(member, user: { user in
                    SVProgressHUD.dismiss()
                    if user != nil {
                        tableView.beginUpdates()
                        self.members.remove(at: indexPath.row)
                        let deletePath = indexPath
                        tableView.deleteRows(at: [deletePath], with: .fade)
                        tableView.endUpdates()
                        
                        tableView.beginUpdates()
                        let insertPath = IndexPath(row: self.friends.count, section: 0)
                        self.friends.append(user!)
                        self.tableView.insertRows(at: [insertPath], with: .fade)
                        tableView.endUpdates()
                    } else {
                        self.showMessage("Can not add this user.", messageType: .error)
                        return
                    }
                })
            }
        }
    }
}

extension MembersController : FIRInviteDelegate {
    
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

extension MembersController : FBSDKAppInviteDialogDelegate {
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didCompleteWithResults results: [AnyHashable : Any]!) {
        print(results)
    }
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didFailWithError error: Error!) {
        print(error)
    }
   
}
