//
//  LoginView.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 25.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import GoogleSignIn

protocol LoginDelegate {
    func didLogin()
}

class LoginView: UIView, GIDSignInDelegate {

    var delegate:LoginDelegate? {
        didSet {
            host = delegate as? UIViewController
            
            GIDSignIn.sharedInstance().clientID = FIRApp.defaultApp()?.options.clientID
            GIDSignIn.sharedInstance().delegate = self
            GIDSignIn.sharedInstance().uiDelegate = host as! GIDSignInUIDelegate
        }
    }
    
    private var host:UIViewController?
    
    // MARK: - Google+ Auth
    
    @IBAction func googleLogin(_ sender: Any) {
        GIDSignIn.sharedInstance().signIn()
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error != nil {
            self.host?.showMessage(error.localizedDescription, messageType: .error)
            return
        }
        let authentication = user.authentication
        let credential = FIRGoogleAuthProvider.credential(withIDToken: (authentication?.idToken)!,
                                                          accessToken: (authentication?.accessToken)!)
        SVProgressHUD.show(withStatus: "Login...")
        FIRAuth.auth()?.signIn(with: credential, completion: { firUser, error in
            SVProgressHUD.dismiss()
            if error != nil {
                self.host?.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
            } else {
                Model.shared.createGoogleUser(firUser!, googleProfile: user.profile)
                self.delegate?.didLogin()
            }
        })
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        try? FIRAuth.auth()?.signOut()
    }
    
    // MARK: - Facebook Auth
    
    @IBAction func facebookLogin(_ sender: Any) {
        FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email","user_friends"], from: host, handler: { result, error in
            if error != nil {
                self.host?.showMessage("Facebook authorization error.", messageType: .error)
                return
            }
            
            SVProgressHUD.show(withStatus: "Login...")
            let params = ["fields" : "id,name,email,picture.width(480).height(480)"]
            let request = FBSDKGraphRequest(graphPath: "me", parameters: params)
            request!.start(completionHandler: { _, result, fbError in
                if fbError != nil {
                    SVProgressHUD.dismiss()
                    self.host?.showMessage(fbError!.localizedDescription, messageType: .error)
                } else {
                    let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                    FIRAuth.auth()?.signIn(with: credential, completion: { firUser, error in
                        if error != nil {
                            SVProgressHUD.dismiss()
                            self.host?.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
                        } else {
                            if let profile = result as? [String:Any] {
                                Model.shared.createFacebookUser(firUser!, profile: profile)
                                SVProgressHUD.dismiss()
                                self.delegate?.didLogin()
                            } else {
                                self.host?.showMessage("Can not read user profile.", messageType: .error)
                                try? FIRAuth.auth()?.signOut()
                            }
                        }
                    })
                }
            })
        })
    }

}
