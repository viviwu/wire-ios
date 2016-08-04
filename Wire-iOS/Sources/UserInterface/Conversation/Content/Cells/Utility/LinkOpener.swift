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


import Foundation

@objc enum LinkOpeningOption: Int {
    case None, Default, Tweetbot

    var displayString: String {
        return displayStringKey.localized
    }
    
    private var displayStringKey: String {
        switch self {
        case .None: return ""
        case .Default: return "open_link.twitter.option.default"
        case .Tweetbot: return "open_link.twitter.option.tweetbot"
        }
    }
}

extension Settings {
    var twitterLinkOpeningOption: LinkOpeningOption {
        set { twitterLinkOpeningOptionRawValue = newValue.rawValue }
        get { return LinkOpeningOption(rawValue: twitterLinkOpeningOptionRawValue) ?? .None }
    }
}

@objc final class LinkOpener: NSObject {

    let settings = Settings.sharedSettings()
    let application = UIApplication.sharedApplication()
    
    let url: NSURL
    
    init(_ url: NSURL) {
        self.url = url
        super.init()
    }
    
    func open(choiceHandler: (options: [LinkOpeningOption], completion: LinkOpeningOption -> Void) -> Void) {
        guard nil != url.tweetbotURL && application.tweetbotInstalled else { application.openURL(url); return }
        let option = settings.twitterLinkOpeningOption
        if option == .None {
            choiceHandler(options: [.Default, .Tweetbot], completion: didelectOption); return
        }
        handleOption(option)
    }
    
    func didelectOption(option: LinkOpeningOption) {
        settings.twitterLinkOpeningOption = option
        handleOption(option)
    }
    
    func handleOption(option: LinkOpeningOption) {
        if let tweetbotURL = url.tweetbotURL where option == .Tweetbot {
            if !application.openURL(tweetbotURL) {
                application.openURL(url)
            }
        } else {
            application.openURL(url)
        }
    }
}

private extension UIApplication {
    var tweetbotInstalled: Bool {
        guard let url = NSURL(string: "tweetbot://") else { return false }
        return canOpenURL(url)
    }
}

private extension NSURL {
    var isTweet: Bool {
        return absoluteString.containsString("twitter.com") &&
            absoluteString.containsString("status")
    }
    
    var tweetbotURL: NSURL? {
        guard isTweet else { return nil }

        let components = [
            "https://twitter.com/",
            "http://twitter.com/",
            "http://mobile.twitter.com/",
            "https://mobile.twitter.com/"
        ]
        let tweetbot = components.reduce(absoluteString) { result, current in
            return result.stringByReplacingStringWithTweetbotURLScheme(current)
        }
        
        return NSURL(string: tweetbot)
    }
}

private extension String {
    func stringByReplacingStringWithTweetbotURLScheme(string: String) -> String {
        return stringByReplacingOccurrencesOfString(string, withString: "tweetbot://")
    }
}

