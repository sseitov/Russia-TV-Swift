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

    var fbButton:UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge()
        
        self.senderId = ""
        self.senderDisplayName = ""
        
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize(width: 36, height: 36)
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: 36, height: 36)
        
        if currentUser() != nil {
            didLogin()
        } else {
            didLogout()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if fbButton != nil {
            fbButton?.center = collectionView.center
        }
    }
    
    // MARK: - Facebook Auth
    
    @IBAction func signOut(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Logout...")
        Model.shared.signOut {
            SVProgressHUD.dismiss()
            self.didLogout()
        }
    }

    func didLogout() {
        setupTitle("РЕГИСТРАЦИЯ")
        self.senderId = ""
        self.senderDisplayName = ""
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.leftBarButtonItem?.isEnabled = false
        inputToolbar.isHidden = true
        
        fbButton = UIButton(frame: CGRect(x: 0, y: 0, width: 130, height: 130))
        fbButton?.setImage(UIImage(named: "fb"), for: .normal)
        fbButton?.addTarget(self, action: #selector(self.facebookSignIn), for: .touchUpInside)
        fbButton?.center = collectionView.center
        collectionView.addSubview(fbButton!)
    }

    func didLogin() {
        setupTitle("ФОРУМ")
        if fbButton != nil {
            fbButton?.removeFromSuperview()
            fbButton = nil
        }
        self.senderId = currentUser()!.uid!
        self.senderDisplayName = currentUser()!.name!
        navigationItem.rightBarButtonItem?.isEnabled = true
        navigationItem.leftBarButtonItem?.isEnabled = true
        inputToolbar.isHidden = false
    }

    func facebookSignIn() {
        FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email","user_friends"], from: self, handler: { result, error in
            if error != nil {
                self.showMessage("Facebook authorization error.", messageType: .error)
                return
            }
            
            SVProgressHUD.show(withStatus: "Login...")
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
