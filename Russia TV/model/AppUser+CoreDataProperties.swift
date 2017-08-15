//
//  AppUser+CoreDataProperties.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 15.08.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData


extension AppUser {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppUser> {
        return NSFetchRequest<AppUser>(entityName: "AppUser")
    }

    @NSManaged public var avatar: String?
    @NSManaged public var email: String?
    @NSManaged public var name: String?
    @NSManaged public var token: String?
    @NSManaged public var uid: String?

}
