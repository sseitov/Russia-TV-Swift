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
import TwitterKit

protocol LoginDelegate {
    func checkAgreement(_ accept: @escaping(Bool) -> ())
    func didLogin()
}

class LoginView: UIView, GIDSignInDelegate {

    var delegate:LoginDelegate? {
        didSet {
            host = delegate as? UIViewController
            
            GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
            GIDSignIn.sharedInstance().delegate = self
            GIDSignIn.sharedInstance().uiDelegate = host as! GIDSignInUIDelegate
        }
    }
    
    private var host:UIViewController?
    
    // MARK: - Twitter Auth
    
    @IBAction func twitterLogin(_ sender: Any) {
        delegate?.checkAgreement({ accept in
            if accept {
                Twitter.sharedInstance().logIn(completion: { session, error in
                    if let error = error {
                        self.host?.showMessage(error.localizedDescription, messageType: .error)
                    } else {
                        let client = TWTRAPIClient.withCurrentUser()
                        client.loadUser(withID: client.userID!, completion: { user, error in
                            let credential = TwitterAuthProvider.credential(withToken: session!.authToken, secret: session!.authTokenSecret)
                            SVProgressHUD.show(withStatus: "Login...")
                            Auth.auth().signIn(with: credential, completion: { firUser, error in
                                SVProgressHUD.dismiss()
                                if error != nil {
                                    self.host?.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
                                } else {
                                    let cashedUser =  Model.shared.createUser(firUser!.uid)
                                    cashedUser.email = "#\(user!.screenName)"
                                    cashedUser.name = user!.name
                                    cashedUser.avatar = user!.profileImageURL
                                    Model.shared.updateUser(cashedUser)
                                    self.delegate?.didLogin()
                                }
                            })
                        })
                    }
                })
            }
        })
    }
    
    // MARK: - Google+ Auth
    
    @IBAction func googleLogin(_ sender: Any) {
        delegate?.checkAgreement({ accept in
            if accept {
                GIDSignIn.sharedInstance().signIn()
            }
        })
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error != nil {
            self.host?.showMessage(error.localizedDescription, messageType: .error)
            return
        }
        let authentication = user.authentication
        let credential = GoogleAuthProvider.credential(withIDToken: (authentication?.idToken)!,
                                                          accessToken: (authentication?.accessToken)!)
        SVProgressHUD.show(withStatus: "Login...")
        Auth.auth().signIn(with: credential, completion: { firUser, error in
            SVProgressHUD.dismiss()
            if error != nil {
                self.host?.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
            } else {
                let cashedUser =  Model.shared.createUser(firUser!.uid)
                cashedUser.email = user.profile.email
                cashedUser.name = user.profile.name
                if user.profile.hasImage {
                    if let url = user.profile.imageURL(withDimension: 100) {
                        cashedUser.avatar = url.absoluteString
                    }
                }
                Model.shared.updateUser(cashedUser)
                self.delegate?.didLogin()
            }
        })
    }
    
    // MARK: - Facebook Auth
    
    @IBAction func facebookLogin(_ sender: Any) {
        delegate?.checkAgreement({ accept in
            if accept {
                FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email","user_friends"], from: self.host, handler: { result, error in
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
                            let credential = FacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                            Auth.auth().signIn(with: credential, completion: { firUser, error in
                                if error != nil {
                                    SVProgressHUD.dismiss()
                                    self.host?.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
                                } else {
                                    if let profile = result as? [String:Any] {
                                        let cashedUser = Model.shared.createUser(firUser!.uid)
                                        cashedUser.email = profile["email"] as? String
                                        cashedUser.name = profile["name"] as? String
                                        if let picture = profile["picture"] as? [String:Any] {
                                            if let data = picture["data"] as? [String:Any] {
                                                cashedUser.avatar = data["url"] as? String
                                            }
                                        }
                                        Model.shared.updateUser(cashedUser)
                                        SVProgressHUD.dismiss()
                                        self.delegate?.didLogin()
                                    } else {
                                        self.host?.showMessage("Can not read user profile.", messageType: .error)
                                        try? Auth.auth().signOut()
                                    }
                                }
                            })
                        }
                    })
                })
            }
        })
    }

}
