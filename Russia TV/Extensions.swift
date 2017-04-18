//
//  Extensions.swift
//  Russia TV
//
//  Created by Sergey Seitov on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension UIFont {
    
    class func condensedFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "HelveticaNeue-CondensedBold", size: size)!
    }
    
    class func mainFont(_ size:CGFloat = 15) -> UIFont {
        return UIFont(name: "HelveticaNeue", size: size)!
    }
    
}

extension UIColor {
    
    class func color(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> UIColor {
        return UIColor(red: CGFloat(r/255.0), green: CGFloat(g/255.0), blue: CGFloat(b/255.0), alpha: CGFloat(a))
    }
    
    class func mainColor() -> UIColor {
        return color(0, 113, 165, 1)
    }
    
}

