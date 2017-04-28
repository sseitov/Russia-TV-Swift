//
//  MembersController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 28.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class MembersController: UITableViewController {

    private var members:[Any] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(NSLocalizedString("members", comment: ""))
        setupBackButton()
        SVProgressHUD.show(withStatus: "Refresh...")
        Model.shared.members({ members in
            SVProgressHUD.dismiss()
            self.members = members.sorted(by: { item1, item2 in
                if let user1 = item1 as? [String:Any], let name1 = user1["name"] as? String,
                    let user2 = item2 as? [String:Any], let name2 = user2["name"] as? String {
                    return name1 < name2
                } else {
                    return false
                }
            })
            self.tableView.reloadData()
        })
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "member", for: indexPath) as! MemberCell
        cell.member = members[indexPath.row] as? [String:Any]
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let member = members[indexPath.row] as? [String:Any] {
            if Model.shared.addUser(member) != nil {
                self.goBack()
            } else {
                self.showMessage("Can not add this user.", messageType: .error)
            }
        }
    }
}
