//
//  AppDelegate.swift
//  MusicBar
//
//  Created by Tomohiro Nishimura on 2016/04/02.
//  Copyright © 2016年 Tomohiro Nishimura. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private let musicBar = MusicBar()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func applicationWillFinishLaunching(notification: NSNotification) {
        let eventManager = NSAppleEventManager.sharedAppleEventManager()
        eventManager.setEventHandler(self, andSelector: #selector(handleGetURLEvent), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    // トークンを保存する
    func handleGetURLEvent(event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
        guard let event = event else {
            return
        }
        guard let URL = event.descriptorForKeyword(AEKeyword(keyDirectObject))?.stringValue else {
            return
        }
        guard let components = NSURLComponents(string: URL) else {
            return
        }
        guard let token = components.queryItems?.filter({ $0.name == "token" }).first?.value else {
            return
        }
        NSUserDefaults.standardUserDefaults().setObject(token, forKey: "token")
        musicBar.updateAuthMenuItem()
    }
}

