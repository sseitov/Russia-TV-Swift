//
//  LoginView.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 25.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase

protocol LoginDelegate {
    func didLogin()
}

class LoginView: UIView {

    var delegate:LoginDelegate?

    @IBAction func googleLogin(_ sender: Any) {
    }
    
    @IBAction func facebookLogin(_ sender: Any) {
        let parent = delegate as? UIViewController
        FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email","user_friends"], from: parent, handler: { result, error in
            if error != nil {
                parent?.showMessage("Facebook authorization error.", messageType: .error)
                return
            }
            
            SVProgressHUD.show(withStatus: "Login...")
            let params = ["fields" : "id,name,email,picture.width(480).height(480)"]
            let request = FBSDKGraphRequest(graphPath: "me", parameters: params)
            request!.start(completionHandler: { _, result, fbError in
                if fbError != nil {
                    SVProgressHUD.dismiss()
                    parent?.showMessage(fbError!.localizedDescription, messageType: .error)
                } else {
                    let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                    FIRAuth.auth()?.signIn(with: credential, completion: { firUser, error in
                        if error != nil {
                            SVProgressHUD.dismiss()
                            parent?.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
                        } else {
                            if let profile = result as? [String:Any] {
                                Model.shared.createFacebookUser(firUser!, profile: profile)
                                SVProgressHUD.dismiss()
                                self.delegate?.didLogin()
                            } else {
                                parent?.showMessage("Can not read user profile.", messageType: .error)
                                try? FIRAuth.auth()?.signOut()
                            }
                        }
                    })
                }
            })
        })
    }

}
