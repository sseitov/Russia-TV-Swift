//
//  InviteController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 18.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase

class InviteController: UITableViewController {

    private var friends:[User] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("УЧАСТНИКИ")
        setupBackButton()
        
        if let token = UserDefaults.standard.value(forKey: "fbToken") as? String {
            SVProgressHUD.show(withStatus: "Load...")
            let params = ["fields" : "name"]
            let request = FBSDKGraphRequest(graphPath: "me/friends/", parameters: params, tokenString: token, version: nil, httpMethod: nil)
            request!.start(completionHandler: { _, result, fbError in
                if let friendList = result as? [String:Any], let list = friendList["data"] as? [Any] {
                    for item in list {
                        if let profile = item as? [String:Any],
                            let id = profile["id"] as? String {
                            if let user = Model.shared.facebookUser(id) {
                                self.friends.append(user)
                            } else {
                                InviteController.addUser(fieldName: "facebookID", fieldValue: id, result: { user in
                                    if user != nil {
                                        self.tableView.beginUpdates()
                                        let indexPath = IndexPath(row: self.friends.count, section: 0)
                                        self.friends.append(user!)
                                        self.tableView.insertRows(at: [indexPath], with: .bottom)
                                        self.tableView.endUpdates()
                                    }
                                })
                            }
                        }
                    }
                }
                SVProgressHUD.dismiss()
                self.tableView.reloadData()
            })
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "my friends with cactus"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "member", for: indexPath) as! MemberCell
        cell.user = friends[indexPath.row]
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    class func addUser(fieldName:String, fieldValue:String, result: @escaping(User?) -> ()) {
        let ref = FIRDatabase.database().reference()
        ref.child("users").queryOrdered(byChild: fieldName).queryEqual(toValue: fieldValue).observeSingleEvent(of: .value, with: { snapshot in
            if let values = snapshot.value as? [String:Any] {
                for uid in values.keys {
                    Model.shared.uploadUser(uid, result: { user in
                        result(user)
                    })
                }
            }
        })
    }

}
