//
//  User+CoreDataProperties.swift
//  Russia TV
//
//  Created by Sergey Seitov on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var avatar: String?
    @NSManaged public var email: String?
    @NSManaged public var name: String?
    @NSManaged public var facebookID: String?
    @NSManaged public var token: String?
    @NSManaged public var uid: String?

}
