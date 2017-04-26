//
//  Model.swift
//  Russia TV
//
//  Created by Sergey Seitov on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import CoreData
import Firebase
import GoogleSignIn

func currentUser() -> User? {
    if let firUser = FIRAuth.auth()?.currentUser {
        if let user = Model.shared.getUser(firUser.uid) {
            return user;
        } else {
            return nil;
        }
    } else {
        return nil
    }
}

let newUserNotification = Notification.Name("NEW_USER")
let newMessageNotification = Notification.Name("NEW_MESSAGE")
let deleteMessageNotification = Notification.Name("DELETE_MESSAGE")
let refreshMessagesNotification = Notification.Name("REFRESH_MESSAGES")

class Model: NSObject {
    
    static let shared = Model()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Date formatter
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
    
    lazy var textDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    lazy var textYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - CoreData stack
    
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "CACTUS", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("CACTUS.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        } catch {
            print("CoreData data error: \(error)")
        }
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                print("Saved data error: \(error)")
            }
        }
    }
    
    // MARK: - SignOut from cloud
    
    func signOut(_ completion: @escaping() -> ()) {
        let ref = FIRDatabase.database().reference()
        ref.child("tokens").child(currentUser()!.uid!).removeValue(completionBlock: { _, _ in
            if let provider = FIRAuth.auth()!.currentUser!.providerData.first {
                if provider.providerID == "facebook.com" {
                    FBSDKLoginManager().logOut()
                } else if provider.providerID == "google.com" {
                    GIDSignIn.sharedInstance().signOut()
                }
            }
            
            try? FIRAuth.auth()?.signOut()
            
            self.newTokenRefHandle = nil
            self.updateTokenRefHandle = nil
            self.newMessageRefHandle = nil
            self.deleteMessageRefHandle = nil
            
            completion()
        })
    }
    
    // MARK: - Cloud observers
    
    func startObservers() {
        if newTokenRefHandle == nil {
            observeTokens()
        }
        if newMessageRefHandle == nil {
            observeMessages()
        }
    }
    
    lazy var storageRef: FIRStorageReference = FIRStorage.storage().reference(forURL: firStorage)
    
    private var newTokenRefHandle: FIRDatabaseHandle?
    private var updateTokenRefHandle: FIRDatabaseHandle?

    private var newMessageRefHandle: FIRDatabaseHandle?
    private var deleteMessageRefHandle: FIRDatabaseHandle?
    
    // MARK: - User table
    
    func createUser(_ uid:String) -> User {
        var user = getUser(uid)
        if user == nil {
            user = NSEntityDescription.insertNewObject(forEntityName: "User", into: managedObjectContext) as? User
            user!.uid = uid
        }
        return user!
    }
    
    func getUser(_ uid:String) -> User? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let user = try? managedObjectContext.fetch(fetchRequest).first as? User {
            return user
        } else {
            return nil
        }
    }

    func addUser(_ data:[String:Any], user: @escaping(User?) -> ()) {
        if let uid = data["uid"] as? String {
            let newUser = self.createUser(uid)
            newUser.setData(data)
            self.getUserToken(uid, token: { token in
                newUser.token = token
                self.saveContext()
                user(newUser)
            })
        } else {
            user(nil)
        }
    }
    
    func deleteUser(_ uid:String) {
        if let user = getUser(uid) {
            let messages = userMessages(user)
            for message in messages {
                managedObjectContext.delete(message)
            }
            managedObjectContext.delete(user)
            self.saveContext()
            NotificationCenter.default.post(name: refreshMessagesNotification, object: nil)
        }
    }

    func uploadUser(_ uid:String, result: @escaping(User?) -> ()) {
        if let existingUser = getUser(uid) {
            result(existingUser)
        } else {
            let ref = FIRDatabase.database().reference()
            ref.child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in
                if let userData = snapshot.value as? [String:Any] {
                    let user = self.createUser(uid)
                    user.setData(userData)
                    self.getUserToken(uid, token: { token in
                        user.token = token
                        self.saveContext()
                        result(user)
                    })
                } else {
                    result(nil)
                }
            })
        }
    }
    
    func updateUser(_ user:User) {
        saveContext()
        let ref = FIRDatabase.database().reference()
        ref.child("users").child(user.uid!).setValue(user.getData())
    }
    
    fileprivate func getUserToken(_ uid:String, token: @escaping(String?) -> ()) {
        let ref = FIRDatabase.database().reference()
        ref.child("tokens").child(uid).observeSingleEvent(of: .value, with: { snapshot in
            if let result = snapshot.value as? String {
                token(result)
            } else {
                token(nil)
            }
        })
    }
    
    func publishToken(_ user:FIRUser,  token:String) {
        let ref = FIRDatabase.database().reference()
        ref.child("tokens").child(user.uid).setValue(token)
    }
    
    fileprivate func observeTokens() {
        let ref = FIRDatabase.database().reference()
        let coordQuery = ref.child("tokens").queryLimited(toLast:25)
        
        newTokenRefHandle = coordQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if let user = self.getUser(snapshot.key) {
                if let token = snapshot.value as? String {
                    user.token = token
                    self.saveContext()
                }
            }
        })
        
        updateTokenRefHandle = coordQuery.observe(.childChanged, with: { (snapshot) -> Void in
            if let user = self.getUser(snapshot.key) {
                if let token = snapshot.value as? String {
                    user.token = token
                    self.saveContext()
                }
            }
        })
    }
    
    func createGoogleUser(_ user:FIRUser, googleProfile: GIDProfileData!) {
        let cashedUser = createUser(user.uid)
        cashedUser.email = googleProfile.email
        cashedUser.name = googleProfile.name
        if googleProfile.hasImage {
            if let url = googleProfile.imageURL(withDimension: 100) {
                cashedUser.avatar = url.absoluteString
            }
        }
        updateUser(cashedUser)
    }

    func createFacebookUser(_ user:FIRUser, profile:[String:Any]) {
        let cashedUser = createUser(user.uid)
        cashedUser.email = profile["email"] as? String
        cashedUser.name = profile["name"] as? String
        if let picture = profile["picture"] as? [String:Any] {
            if let data = picture["data"] as? [String:Any] {
                cashedUser.avatar = data["url"] as? String
            }
        }
        updateUser(cashedUser)
    }
    
    func getFriends() -> [User] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        fetchRequest.predicate = NSPredicate(format: "uid != %@", currentUser()!.uid!)
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [User] {
            return all
        } else {
            return []
        }
    }
    
    func members(_ completion: @escaping([Any]) -> ()) {
        let ref = FIRDatabase.database().reference()
        ref.child("users").observeSingleEvent(of: .value, with: { snapshot in
            if let values = snapshot.value as? [String:Any] {
                var users:[Any] = []
                for (key, value) in values {
                    if self.getUser(key) == nil {
                        var user = value as? [String:Any]
                        if user != nil {
                            user!["uid"] = key
                            users.append(user!)
                        }
                    }
                }
                let next = NSCondition()
                var live:[Any] = []
                DispatchQueue.global().async {
                    for item in users {
                        DispatchQueue.main.async {
                            let user = item as? [String:Any]
                            let uid = user!["uid"] as? String
                            self.getUserToken(uid!, token: { token in
                                if token != nil {
                                    live.append(user!)
                                }
                                next.lock()
                                next.signal()
                                next.unlock()
                            })
                        }
                        next.lock()
                        next.wait()
                        next.unlock()
                    }
                    DispatchQueue.main.async {
                        completion(live)
                    }
                }
            } else {
                completion([])
            }
        })
    }
    
    // MARK: - Message table
    
    func createMessage(_ uid:String) -> Message {
        var message = getMessage(uid)
        if message == nil {
            message = NSEntityDescription.insertNewObject(forEntityName: "Message", into: managedObjectContext) as? Message
            message!.uid = uid
        }
        return message!
    }

    func getMessage(_ uid:String) -> Message? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let message = try? managedObjectContext.fetch(fetchRequest).first as? Message {
            return message
        } else {
            return nil
        }
    }
    
    func myMessage(_ date:Date) -> Message? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate1 = NSPredicate(format: "from = %@", currentUser()!.uid!)
        let predicate2 = NSPredicate(format: "date = %@", date as NSDate)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        if let message = try? managedObjectContext.fetch(fetchRequest).first as? Message {
            return message
        } else {
            return nil
        }
    }
    
    func userMessages(_ user:User) -> [Message] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.predicate = NSPredicate(format: "from = %@", user.uid!)
        
        do {
            if let all = try managedObjectContext.fetch(fetchRequest) as? [Message] {
                return all
            } else {
                return []
            }
        } catch {
            return []
        }
    }
    
    func deleteMessage(_ message:Message, completion: @escaping() -> ()) {
        let ref = FIRDatabase.database().reference()
        if let image = message.imageURL {
            self.storageRef.child(image).delete(completion: { _ in
                ref.child("messages").child(message.uid!).removeValue(completionBlock:{_, _ in
                    completion()
                })
            })
        } else {
            ref.child("messages").child(message.uid!).removeValue(completionBlock: { _, _ in
                completion()
            })
        }
    }

    func chatMessages() -> [Message] {
        if currentUser() == nil {
            return []
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Message] {
            return all
        } else {
            return []
        }
    }

    func clearMessages() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        _ = try? persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
    }
    
    private func observeMessages() {
        let ref = FIRDatabase.database().reference()
        let messageQuery = ref.child("messages").queryLimited(toLast:25)
        
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if currentUser() != nil && self.getMessage(snapshot.key) == nil {
                let messageData = snapshot.value as! [String:Any]
                if let from = messageData["from"] as? String {
                    if self.getUser(from) != nil {
                        let message = self.createMessage(snapshot.key)
                        message.setData(messageData, completion: {
                            NotificationCenter.default.post(name: newMessageNotification, object: message)
                        })
                    }
                } else {
                    print("Error! Could not decode message data \(messageData)")
                }
            }
        })
        
        deleteMessageRefHandle = messageQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            if let message = self.getMessage(snapshot.key) {
                NotificationCenter.default.post(name: deleteMessageNotification, object: message)
                self.managedObjectContext.delete(message)
                self.saveContext()
            }
        })
    }
    
    func sendTextMessage(_ text:String) {
        let ref = FIRDatabase.database().reference()
        let dateStr = dateFormatter.string(from: Date())
        let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                        "text" : text,
                                        "date" : dateStr]
        ref.child("messages").childByAutoId().setValue(messageItem)
    }
    
    func sendImageMessage(_ image:UIImage, result:@escaping (NSError?) -> ()) {
        if currentUser() == nil {
            return
        }
        if let imageData = UIImageJPEGRepresentation(image, 0.5) {
            let meta = FIRStorageMetadata()
            meta.contentType = "image/jpeg"
            self.storageRef.child(UUID().uuidString).put(imageData, metadata: meta, completion: { metadata, error in
                if error != nil {
                    result(error as NSError?)
                } else {
                    let ref = FIRDatabase.database().reference()
                    let dateStr = self.dateFormatter.string(from: Date())
                    let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                                    "image" : metadata!.path!,
                                                    "date" : dateStr]
                    ref.child("messages").childByAutoId().setValue(messageItem)
                    result(nil)
                }
            })
        }
    }
    
    func sendLocationMessage(_ coordinate:CLLocationCoordinate2D) {
        let ref = FIRDatabase.database().reference()
        let dateStr = dateFormatter.string(from: Date())
        let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                        "date" : dateStr,
                                        "latitude" : coordinate.latitude,
                                        "longitude" : coordinate.longitude]
        ref.child("messages").childByAutoId().setValue(messageItem)
    }

}
