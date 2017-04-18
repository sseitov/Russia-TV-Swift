//
//  ForumController.swift
//  Russia TV
//
//  Created by Sergey Seitov on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase

class ForumController: JSQMessagesViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("ФОРУМ")
        self.edgesForExtendedLayout = UIRectEdge()
        
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize(width: 36, height: 36)
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: 36, height: 36)
        
        if currentUser() != nil {
            self.senderId = currentUser()!.uid!
            self.senderDisplayName = currentUser()!.name!
            inputToolbar.isHidden = false
            navigationItem.rightBarButtonItem?.isEnabled = true
        } else {
            self.senderId = ""
            self.senderDisplayName = ""
            inputToolbar.isHidden = true
            navigationItem.rightBarButtonItem?.isEnabled = false
            facebookSignIn()
        }
    }
    
    // MARK: - Facebook Auth
    
    func didLogin() {
        self.senderId = currentUser()!.uid!
        self.senderDisplayName = currentUser()!.name!
        inputToolbar.isHidden = false
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    func facebookSignIn() { // read_custom_friendlists
        FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email","user_friends"], from: self, handler: { result, error in
            if error != nil {
                self.showMessage("Facebook authorization error.", messageType: .error)
                return
            }
            
            SVProgressHUD.show(withStatus: "Login...") // interested_in
            let params = ["fields" : "name,email,picture.width(480).height(480)"]
            let request = FBSDKGraphRequest(graphPath: "me", parameters: params)
            request!.start(completionHandler: { _, result, fbError in
                if fbError != nil {
                    SVProgressHUD.dismiss()
                    self.showMessage(fbError!.localizedDescription, messageType: .error)
                } else {
                    print(FBSDKAccessToken.current().tokenString)
                    UserDefaults.standard.set(FBSDKAccessToken.current().tokenString, forKey: "fbToken")
                    UserDefaults.standard.synchronize()
                    let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                    FIRAuth.auth()?.signIn(with: credential, completion: { firUser, error in
                        if error != nil {
                            SVProgressHUD.dismiss()
                            self.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
                        } else {
                            if let profile = result as? [String:Any] {
                                Model.shared.createFacebookUser(firUser!, profile: profile)
                                SVProgressHUD.dismiss()
                                self.didLogin()
                            } else {
                                self.showMessage("Can not read user profile.", messageType: .error)
                                try? FIRAuth.auth()?.signOut()
                            }
                        }
                    })
                }
            })
        })
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
