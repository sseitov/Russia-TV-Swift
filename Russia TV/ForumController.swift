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
    var messages:[JSQMessage] = []

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if currentUser() != nil {
            SVProgressHUD.show(withStatus: "Refresh...")
            Model.shared.findFriends {
                SVProgressHUD.dismiss()
            }
            scrollToBottom(animated: true)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if fbButton != nil {
            fbButton?.center = collectionView.center
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
        
        NotificationCenter.default.removeObserver(self)
        Model.shared.clearMessages()
        messages.removeAll()
        collectionView.reloadData()
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
        
        let cashedMessages = Model.shared.chatMessages()
        for message in cashedMessages {
            if let jsqMessage = addMessage(message) {
                messages.append(jsqMessage)
                self.finishReceivingMessage()
            }
        }

        Model.shared.startObservers()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.newMessageNotify(_:)),
                                               name: newMessageNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.deleteMessageNotify(_:)),
                                               name: deleteMessageNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.refreshMessageNotify(_:)),
                                               name: refreshUserNotification,
                                               object: nil)

    }

    // MARK: - Message management
    
    func newMessageNotify(_ notify:Notification) {
        if let message = notify.object as? Message {
            if let jsqMessage = addMessage(message) {
                messages.append(jsqMessage)
                self.finishReceivingMessage()
            }
        }
    }
    
    func deleteMessageNotify(_ notify:Notification) {
        if let message = notify.object as? Message {
            if let msg = getMsg(sender:message.from!, date:message.date! as Date) {
                if let index = messages.index(of: msg) {
                    self.collectionView.performBatchUpdates({
                        self.messages.remove(at: index)
                        self.collectionView.deleteItems(at: [IndexPath(row:index, section:0)])
                    }, completion: { _ in
                    })
                }
            }
        }
    }

    func refreshMessageNotify(_ notify:Notification) {
        if let indexPath = notify.object as? IndexPath {
            collectionView.reloadItems(at: [indexPath])
        }
    }
    
    private func addMessage(_ message:Message) -> JSQMessage? {
        if let user = Model.shared.getUser(message.from!) {
            let name = user.name!
            if message.imageData != nil {
                let photo = JSQPhotoMediaItem(image: UIImage(data: message.imageData! as Data))
                photo!.appliesMediaViewMaskAsOutgoing = (message.from! == currentUser()!.uid!)
                return JSQMessage(senderId: message.from!, senderDisplayName: name, date: message.date! as Date, media: photo)
            } else if message.location() != nil {
                let point = LocationMediaItem(location: nil)
                point?.messageLocation = message.location()
                point!.appliesMediaViewMaskAsOutgoing = (message.from! == currentUser()!.uid!)
                point!.setLocation(CLLocation(latitude: message.latitude, longitude: message.longitude), withCompletionHandler: {
                    self.collectionView.reloadData()
                })
                return JSQMessage(senderId: message.from!, senderDisplayName: name, date: message.date! as Date, media: point)
            } else if message.text != nil {
                return JSQMessage(senderId: message.from!, senderDisplayName: name, date: message.date! as Date, text: message.text!)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    private func getMsg(sender:String, date:Date) -> JSQMessage? {
        for msg in messages {
            if msg.senderId == sender && msg.date.timeIntervalSince1970 == date.timeIntervalSince1970 {
                return msg
            }
        }
        return nil
    }

    // MARK: - Facebook Auth
    
    @IBAction func signOut(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Logout...")
        Model.shared.signOut {
            SVProgressHUD.dismiss()
            self.didLogout()
        }
    }

    func facebookSignIn() {
        FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email","user_friends"], from: self, handler: { result, error in
            if error != nil {
                self.showMessage("Facebook authorization error.", messageType: .error)
                return
            }
            
            SVProgressHUD.show(withStatus: "Login...")
            let params = ["fields" : "id,name,email,picture.width(480).height(480)"]
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
    
    // MARK: - Send / receive messages
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        Model.shared.sendTextMessage(text)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let actionView = ActionSheet.create(
            title: "Choose Data",
            actions: ["Photo from Camera Roll", "Create photo use Camera", "My current location"],
            handler1: {
                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = false
                imagePicker.sourceType = .photoLibrary
                imagePicker.delegate = self
                imagePicker.modalPresentationStyle = .formSheet
                if let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15) {
                    imagePicker.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.mainColor(), NSFontAttributeName : font]
                }
                imagePicker.navigationBar.tintColor = UIColor.mainColor()
                self.present(imagePicker, animated: true, completion: nil)
        }, handler2: {
            let imagePicker = UIImagePickerController()
            imagePicker.allowsEditing = false
            imagePicker.sourceType = .camera
            imagePicker.delegate = self
            self.present(imagePicker, animated: true, completion: nil)
        }, handler3: {
            SVProgressHUD.show(withStatus: "Get Location...")
            LocationManager.shared.updateLocation({ location in
                SVProgressHUD.dismiss()
                if location != nil {
                    Model.shared.sendLocationMessage(location!.coordinate)
                } else {
                    self.showMessage("Can not get your location.", messageType: .error)
                }
            })
        })
        
        actionView?.show()
    }
    
    // MARK: - JSQMessagesCollectionView delegate
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.mainColor())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        let message = messages[indexPath.item]
        return NSAttributedString(string: Model.shared.textDateFormatter.string(from: message.date))
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, heightForCellBottomLabelAt indexPath:IndexPath) -> CGFloat {
        return 20
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item]
        return JSQAvatar(message.senderId, indexPath: indexPath)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.white
        } else {
            cell.textView?.textColor = UIColor.black
        }
        return cell
    }
    
    private func IS_PAD() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        let message = messages[indexPath.item]
        if message.isMediaMessage || message.senderId == currentUser()!.uid! {
            if IS_PAD() {
                if message.senderId == currentUser()!.uid! {
                    var handler:CompletionBlock?
                    var titles = ["Delete message"]
                    if (message.media as? JSQPhotoMediaItem) != nil {
                        handler = {
                            self.performSegue(withIdentifier: "showPhoto", sender: message)
                        }
                        titles.insert("Show photo", at: 0)
                    } else if (message.media as? LocationMediaItem) != nil {
                        handler = {
                            self.performSegue(withIdentifier: "showMap", sender: message)
                        }
                        titles.insert("Show map", at: 0)
                    }
                    let alert = ActionSheet.create(title: "Action", actions: titles, handler1: handler, handler2: {
                        if let msg = Model.shared.myMessage(message.date) {
                            SVProgressHUD.show(withStatus: "Delete...")
                            Model.shared.deleteMessage(msg, completion: {
                                SVProgressHUD.dismiss()
                            })
                        }
                    })
                    alert?.show()
                } else {
                    if (message.media as? JSQPhotoMediaItem) != nil {
                        let alert = createQuestion("Show photo?", acceptTitle: "Show", cancelTitle: "Cancel", acceptHandler: {
                            self.performSegue(withIdentifier: "showPhoto", sender: message)
                        })
                        alert?.show()
                    } else if (message.media as? LocationMediaItem) != nil {
                        let alert = createQuestion("Show map?", acceptTitle: "Show", cancelTitle: "Cancel", acceptHandler: {
                            self.performSegue(withIdentifier: "showMap", sender: message)
                        })
                        alert?.show()
                    }
                }
            } else {
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                if (message.media as? JSQPhotoMediaItem) != nil {
                    alert.addAction(UIAlertAction(title: "show photo", style: .default, handler: { _ in
                        self.performSegue(withIdentifier: "showPhoto", sender: message)
                    }))
                }
                if (message.media as? LocationMediaItem) != nil {
                    alert.addAction(UIAlertAction(title: "show map", style: .default, handler: { _ in
                        self.performSegue(withIdentifier: "showMap", sender: message)
                    }))
                }
                
                if message.senderId == currentUser()!.uid! {
                    alert.addAction(UIAlertAction(title: "delete message", style: .destructive, handler: { _ in
                        if let msg = Model.shared.myMessage(message.date) {
                            SVProgressHUD.show(withStatus: "Delete...")
                            Model.shared.deleteMessage(msg, completion: {
                                SVProgressHUD.dismiss()
                            })
                        }
                    }))
                }
                alert.addAction(UIAlertAction(title: "cancel", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - UIImagePickerController delegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: {
            if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
                SVProgressHUD.show(withStatus: "Send...")
                Model.shared.sendImageMessage(pickedImage, result: { error in
                    SVProgressHUD.dismiss()
                    if error != nil {
                        self.showMessage(error!.localizedDescription, messageType: .error)
                    } else {
                        JSQSystemSoundPlayer.jsq_playMessageSentSound()
                        self.finishSendingMessage()
                    }
                })
            }
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let message = sender as! JSQMessage
            let controller = segue.destination as! PhotoController
            controller.date = message.date
            let photo = message.media as! JSQPhotoMediaItem
            controller.image = photo.image
        } else if segue.identifier == "showMap" {
            let controller = segue.destination as! LocationController
            let message = sender as! JSQMessage
            let point = message.media as! LocationMediaItem
            controller.userLocation = point.messageLocation
            controller.locationDate = message.date
        }
    }

}
