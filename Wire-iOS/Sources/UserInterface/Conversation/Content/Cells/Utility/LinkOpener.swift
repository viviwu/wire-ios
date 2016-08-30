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

enum LinkApplication {
    case Twitter, Maps, Browser
}

protocol LinkOpenOption {
    var displayString: String { get }
    var application: LinkApplication { get }
    static func canOpenUrl(url: NSURL) -> Bool
}

enum TweetOpeningOption: Int, LinkOpenOption {
    
    case None, Default, Tweetbot
    
    static var allOptions: [LinkOpenOptions] {
        return [
            TweetOpeningOption.None,
            TweetOpeningOption.Default,
            TweetOpeningOption.Tweetbot
        ]
    }
    
    var displayString: String { return displayStringKey.localized }
    var application: LinkApplication { return .Twitter }
    
    private var displayStringKey: String {
        switch self {
        case .None: return ""
        case .Default: return "open_link.twitter.option.default"
        case .Tweetbot: return "open_link.twitter.option.tweetbot"
        }
    }
    
    static func canOpenUrl(url: NSURL) -> Bool {
        guard UIApplication.sharedApplication().tweetbotInstalled else { return false }
        return nil != url.tweetbotURL
    }
    
    static var savedOption: TweetOpeningOption {
        set { Settings.sharedSettings().twitterLinkOpeningOptionRawValue = newValue.rawValue }
        get { return TweetOpeningOption(rawValue: Settings.sharedSettings().twitterLinkOpeningOptionRawValue) ?? .None }
    }
}

enum MapsOpeningOption: Int, LinkOpenOption {
    case None, Default, Google
    
    var application: LinkApplication { return .Maps }
    
    var displayString: String { return "INSERT_TITLE" }
    
    static func canOpenUrl(url: NSURL) -> Bool {
        return false
    }
}

protocol LinkOpenerDelegate: class {
    func linkOpener(opener: LinkOpener, selectPrefferedOption: [LinkOpenOption], withCompletion: LinkOpenOption -> Void)
}

@objc final class LinkOpener: NSObject {

    let settings = Settings.sharedSettings()
    let application = UIApplication.sharedApplication()
    weak var delegate: LinkOpenerDelegate?
    
    let url: NSURL
    
    init(_ url: NSURL) {
        self.url = url
        super.init()
    }

    func open<LinkType: LinkOpenOption>(choiceHandler: (options: [LinkType], completion: LinkType -> Void) -> Void) {
        if TweetOpeningOption.canOpenUrl(url) {
            if TweetOpeningOption.savedOption != .None {
                delegate?.linkOpener(self, selectPrefferedOption: TweetOpeningOption.allOptions, withCompletion: didSelectOption)
            }
        } else if MapsOpeningOption.canOpenUrl(url) {
            
        }
        
        
        guard nil != url.tweetbotURL && application.tweetbotInstalled else { application.openURL(url); return }
        let option = settings.twitterLinkOpeningOption
        if option == .None {
            delegate?.linkOpener(self, selectPrefferedOption: [TweetOpeningOption.Default, TweetOpeningOption.Tweetbot], withCompletion: didSelectOption)
        }

        handleOption(option)
    }
    
    func didSelectOption(option: LinkOpenOption) {
        if let tweetOption = option as? TweetOpeningOption {
            settings.twitterLinkOpeningOption = tweetOption
            handleOption(option)
        }
    }
    
    func handleOption(option: LinkOpenOption) {
        if let tweetOption = option as? TweetOpeningOption, tweetbotURL = url.tweetbotURL where tweetOption == .Tweetbot {
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

