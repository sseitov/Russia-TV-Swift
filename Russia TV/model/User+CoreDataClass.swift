//
//  User+CoreDataClass.swift
//  Russia TV
//
//  Created by Sergey Seitov on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData


public class User: NSManagedObject {
    
    func getData() -> [String:Any] {
        var profile:[String : Any] = [:]
        if email != nil {
            profile["email"] = email!
        }
        if name != nil {
            profile["name"] = name!
        }
        if avatar != nil {
            profile["avatar"] = avatar!
        }
        if token != nil {
            profile["token"] = avatar!
        }
        return profile
    }
    
    func setData(_ profile:[String : Any]) {
        email = profile["email"] as? String
        name = profile["name"] as? String
        avatar = profile["avatar"] as? String
        token = profile["token"] as? String
    }

}
