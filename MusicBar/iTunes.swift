//
//  iTunes.swift
//  MenuBarTest
//
//  Created by Tomohiro Nishimura on 2016/04/02.
//  Copyright © 2016年 Tomohiro Nishimura. All rights reserved.
//

import Cocoa
import ScriptingBridge


@objc protocol iTunesTrack {
    optional var name: String { get }
    optional var album:  String { get }
    optional var artist: String { get }
}

extension SBObject: iTunesTrack {

}

class iTunes {
    private let iTunesApplication = SBApplication(bundleIdentifier: "com.apple.iTunes")!

    private static let instance = iTunes()

    class func sharedApplication() -> iTunes {
        return instance
    }

    func currentTrack() -> iTunesTrack {
        return iTunesApplication.valueForKey("currentTrack") as! iTunesTrack
    }
}
