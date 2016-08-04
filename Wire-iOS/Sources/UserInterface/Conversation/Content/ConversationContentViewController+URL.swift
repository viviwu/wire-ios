//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//


import UIKit

extension ConversationContentViewController {
    @objc func openURL(url: NSURL) {
        LinkOpener(url).open { [weak self] options, completion in
            let alert = UIAlertController(
                title: "open_link.twitter.alert.title".localized,
                message: "open_link.twitter.alert.message".localized,
                preferredStyle: .Alert
            )
            options.forEach { option in
                let action = UIAlertAction(title: option.displayString, style: .Default) { action in
                    alert.dismissViewControllerAnimated(true, completion: nil)
                    completion(option)
                }
                alert.addAction(action)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            alert.addAction(cancelAction)
            self?.presentViewController(alert, animated: true, completion: nil)
        }
    }
}