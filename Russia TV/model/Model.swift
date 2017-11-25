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
import TwitterKit

func currentUser() -> AppUser? {
    if let firUser = Auth.auth().currentUser {
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
        let ref = Database.database().reference()
        ref.child("tokens").child(currentUser()!.uid!).removeValue(completionBlock: { _, _ in
            if let provider = Auth.auth().currentUser!.providerData.first {
                print(provider.providerID)
                if provider.providerID == "facebook.com" {
                    FBSDKLoginManager().logOut()
                } else if provider.providerID == "google.com" {
                    GIDSignIn.sharedInstance().signOut()
                } else if provider.providerID == "twitter.com" {
                    let client = TWTRAPIClient.withCurrentUser()
                    if let uid = client.userID {
                        Twitter.sharedInstance().sessionStore.logOutUserID(uid)
                    }
                }
            }
            ref.child("users").child(currentUser()!.uid!).removeValue(completionBlock: { _, _ in
                self.clearMessages()
                self.clearUsers()
                try? Auth.auth().signOut()
                
                self.newTokenRefHandle = nil
                self.updateTokenRefHandle = nil
                self.newMessageRefHandle = nil
                self.deleteMessageRefHandle = nil
                
                completion()
            })
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
    
    lazy var storageRef: StorageReference = Storage.storage().reference(forURL: firStorage)
    
    private var newTokenRefHandle: DatabaseHandle?
    private var updateTokenRefHandle: DatabaseHandle?

    private var newMessageRefHandle: DatabaseHandle?
    private var deleteMessageRefHandle: DatabaseHandle?
    
    // MARK: - User table
    
    func createUser(_ uid:String) -> AppUser {
        var user = getUser(uid)
        if user == nil {
            user = NSEntityDescription.insertNewObject(forEntityName: "AppUser", into: managedObjectContext) as? AppUser
            user!.uid = uid
        }
        return user!
    }
    
    func getUser(_ uid:String) -> AppUser? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AppUser")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let user = try? managedObjectContext.fetch(fetchRequest).first as? AppUser {
            return user
        } else {
            return nil
        }
    }

    func addUser(_ data:[String:Any]) -> AppUser? {
        if let uid = data["uid"] as? String {
            let newUser = self.createUser(uid)
            newUser.setData(data)
            saveContext()
            return newUser
        } else {
            return nil
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

    func uploadUser(_ uid:String, result: @escaping(AppUser?) -> ()) {
        if let existingUser = getUser(uid) {
            result(existingUser)
        } else {
            let ref = Database.database().reference()
            ref.child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in
                if let userData = snapshot.value as? [String:Any] {
                    let user = self.createUser(uid)
                    user.setData(userData)
                } else {
                    result(nil)
                }
            })
        }
    }
    
    func updateUser(_ user:AppUser) {
        user.token = Messaging.messaging().fcmToken
        saveContext()
        let ref = Database.database().reference()
        ref.child("users").child(user.uid!).setValue(user.getData())
    }
    
    func publishToken(_ user:AppUser,  token:String) {
        user.token = token
        saveContext()
        let ref = Database.database().reference()
        ref.child("tokens").child(user.uid!).setValue(token)
    }
    
    fileprivate func observeTokens() {
        let ref = Database.database().reference()
        let coordQuery = ref.child("tokens").queryLimited(toLast:25)
        
        newTokenRefHandle = coordQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if let user = self.getUser(snapshot.key) {
                if let token = snapshot.value as? String {
                    user.token = token
                    self.updateUser(user)
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
    
    func getFriends() -> [AppUser] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AppUser")
        fetchRequest.predicate = NSPredicate(format: "uid != %@", currentUser()!.uid!)
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [AppUser] {
            return all
        } else {
            return []
        }
    }
    
    func members(_ completion: @escaping([Any]) -> ()) {
        let ref = Database.database().reference()
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
                completion(users)
            } else {
                completion([])
            }
        })
    }
    
    func clearUsers() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AppUser")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        _ = try? persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
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
    
    func userMessages(_ user:AppUser) -> [Message] {
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
        let ref = Database.database().reference()
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
        let ref = Database.database().reference()
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
        let ref = Database.database().reference()
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
            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            self.storageRef.child(UUID().uuidString).putData(imageData, metadata: meta, completion: { metadata, error in
                if error != nil {
                    result(error as NSError?)
                } else {
                    let ref = Database.database().reference()
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
        let ref = Database.database().reference()
        let dateStr = dateFormatter.string(from: Date())
        let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                        "date" : dateStr,
                                        "latitude" : coordinate.latitude,
                                        "longitude" : coordinate.longitude]
        ref.child("messages").childByAutoId().setValue(messageItem)
    }

}
