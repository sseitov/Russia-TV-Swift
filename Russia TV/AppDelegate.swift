//
//  AppDelegate.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 24.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import UserNotifications
import GoogleSignIn
import Fabric
import TwitterKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var tabBarController: UITabBarController?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // Use Firebase library to configure APIs
        FirebaseOptions.defaultOptions()?.deepLinkURLScheme = "cactus"
        FirebaseApp.configure()

        // Register_for_notifications
        
        if #available(iOS 10.0, *) {
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
            
            UNUserNotificationCenter.current().delegate = self
            
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()

        // Connect Google auth
        GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
        
        // Connect FBSDK auth
        Invites.applicationDidFinishLaunching(options: launchOptions)
        FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)

        // Connect Twitter auth
        Fabric.with([Twitter.self])
        
        // UI additional
        SVProgressHUD.setDefaultStyle(.custom)
        SVProgressHUD.setBackgroundColor(UIColor.mainColor())
        SVProgressHUD.setForegroundColor(UIColor.white)
        
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedStringKey.font : UIFont.condensedFont()], for: .normal)
        SVProgressHUD.setFont(UIFont.condensedFont())
        
        tabBarController = window?.rootViewController as? UITabBarController
        
        UITabBar.appearance().tintColor = UIColor.white
        if #available(iOS 10.0, *) {
            UITabBar.appearance().unselectedItemTintColor = UIColor.color(204, 204, 204, 1)
        }
        
        return true
    }
    
    // MARK: - TabBar visible

    func setTabBarVisible(visible: Bool, animated: Bool, completion: @escaping (Bool)->Void) {
        // bail if the current state matches the desired state
        if (tabBarIsVisible() == visible) {
            return completion(true)
        }
        
        // get a frame calculation ready
        let height = tabBarController!.tabBar.frame.size.height
        let offsetY = (visible ? -height : height)
        
        // zero duration means no animation
        let duration = (animated ? 0.3 : 0.0)
        
        UIView.animate(withDuration: duration, animations: {
            let frame = self.tabBarController!.tabBar.frame
            self.tabBarController!.tabBar.frame = frame.offsetBy(dx: 0, dy: offsetY);
        }, completion: { finished in
            completion(finished)
        })
    }
    
    func tabBarIsVisible() -> Bool {
        return tabBarController!.tabBar.frame.origin.y < window!.rootViewController!.view.frame.maxY
    }
    
    // MARK: - Application delegate
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if (Twitter.sharedInstance().application(app, open: url, options: options)) {
            return true
        } else if url.scheme!.hasPrefix("com.google") {
            return self.application(app, open: url, sourceApplication: options[.sourceApplication] as? String, annotation: "")
        } else {
            return FBSDKApplicationDelegate.sharedInstance().application(app, open: url, options: options)
        }
    }
 
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication, annotation: annotation)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        guard let dynamicLinks = DynamicLinks.dynamicLinks() else {
            return false
        }
        
        let handled = dynamicLinks.handleUniversalLink(userActivity.webpageURL!) { (dynamiclink, error) in
            if dynamiclink != nil {
            }
        }
        
        return handled
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if application.applicationState != .active {
            if let pushTypeStr = userInfo["pushType"] as? String, let pushType = Int(pushTypeStr) {
                print("push with type \(pushType)")
            }
        }
        completionHandler(.newData)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
            Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
            Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        if let video = window?.rootViewController as? ChannelsController {
            video.refreshTable()
        }
        if let currUser = currentUser(), let fcmToken = Messaging.messaging().fcmToken {
            Model.shared.publishToken(currUser, token: fcmToken)
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        FBSDKAppEvents.activateApp()
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }
}

// MARK: - NotificationCenter delegate

@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        center.removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = -1
        let nav = window!.rootViewController as! UINavigationController
        nav.popToRootViewController(animated: false)
    }
}

extension AppDelegate : MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        Messaging.messaging().shouldEstablishDirectChannel = true
        if let currUser = currentUser() {
            Model.shared.publishToken(currUser, token: fcmToken)
        }
    }
    
}
