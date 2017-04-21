//
//  Extensions.swift
//  Russia TV
//
//  Created by Sergey Seitov on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension String {
    func isEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: self)
    }
}

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
    
    class func errorColor() -> UIColor {
        return color(240, 90, 80, 1)
    }

}

extension UIImage {
    class func imageWithColor(_ color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    func inCircle() -> UIImage {
        let newImage = self.copy() as! UIImage
        let cornerRadius = self.size.height/2
        UIGraphicsBeginImageContextWithOptions(self.size, false, 1.0)
        let bounds = CGRect(origin: CGPoint(), size: self.size)
        UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).addClip()
        newImage.draw(in: bounds)
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage!
    }
}

extension UIView {
    
    func setupBorder(_ color:UIColor, radius:CGFloat) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = 1
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
}

extension UIViewController {
    
    func setupTitle(_ text:String) {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        label.textAlignment = .center
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15)
        label.text = text
        label.textColor = UIColor.white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        navigationItem.titleView = label
    }
    
    func setupBackButton() {
        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(self.goBack)
    }
    
    func goBack() {
        _ = self.navigationController!.popViewController(animated: true)
    }
    
    // MARK: - alerts
    
    func showMessage(_ error:String, messageType:MessageType, messageHandler: (() -> ())? = nil) {
        var title:String = ""
        switch messageType {
        case .success:
            title = NSLocalizedString("Success", comment: "")
        case .information:
            title = NSLocalizedString("Information", comment: "")
        default:
            title = NSLocalizedString("Error", comment: "")
        }
        let alert = LGAlertView.decoratedAlert(withTitle:title, message: error, cancelButtonTitle: "OK", cancelButtonBlock: { alert in
            if messageHandler != nil {
                messageHandler!()
            }
        })
        alert!.titleLabel.textColor = messageType == .error ? UIColor.errorColor() : UIColor.mainColor()
        alert?.show()
    }
    
    func createQuestion(_ question:String, acceptTitle:String, cancelTitle:String, acceptHandler:@escaping () -> (), cancelHandler: (() -> ())? = nil) -> LGAlertView? {
        
        let alert = LGAlertView.alert(
            withTitle: "Attention!",
            message: question,
            cancelButtonTitle: cancelTitle,
            otherButtonTitle: acceptTitle,
            cancelButtonBlock: { alert in
                if cancelHandler != nil {
                    cancelHandler!()
                }
        },
            otherButtonBlock: { alert in
                alert?.dismiss()
                acceptHandler()
        })
        return alert
    }
}

