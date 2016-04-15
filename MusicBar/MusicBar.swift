//
//  MusicBar.swift
//  MenuBarTest
//
//  Created by Tomohiro Nishimura on 2016/04/02.
//  Copyright © 2016年 Tomohiro Nishimura. All rights reserved.
//

import Cocoa
import AppKit
import Alamofire

private struct Track {
    let title: String
    let artist: String
    let album: String
    let storeURL: NSURL?

    var storeID: String? {
        guard let storeURL = storeURL else {
            return nil
        }

        guard let components = NSURLComponents(URL: storeURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let queryItems = components.queryItems
        return queryItems?.filter { $0.name == "i" }.first?.value
    }
}

class MusicBar: NSObject {
    private let iTunesNotificationName = "com.apple.iTunes.playerInfo"


    private static let HOST = NSURL(string: "http://localhost:4567/")!

    private static let SITE_URL = NSURL(string: "http://localhost:4567")!

    enum Endpoint {
        case Listen
        case Recents

        func URL() -> NSURL {
            switch self {
            case .Listen:
                return NSURL(string: "/listen", relativeToURL: HOST)!
            case .Recents:
                return NSURL(string: "/recents", relativeToURL: HOST)!
            }
        }
    }

    private var track: Track?

    private let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    private let songInfoMenuItem = NSMenuItem()
    private let authMenuItem = NSMenuItem()

    private let playingImage = NSImage(named: "playing")!
    private let pauseImage   = NSImage(named: "pause")!

    override init() {
        super.init()

        songInfoMenuItem.hidden = true

        let menu = NSMenu()
        menu.autoenablesItems = true
        menu.addItem(songInfoMenuItem)
        menu.addItem(NSMenuItem.separatorItem())

        let openSiteMenuItem = menu.addItemWithTitle("サイトをみる", action: #selector(openSite), keyEquivalent: "")
        openSiteMenuItem?.target = self
        menu.addItem(NSMenuItem.separatorItem())

        let token = NSUserDefaults.standardUserDefaults().stringForKey("token")

        authMenuItem.title = (token == nil) ? "ログイン" : "ログアウト"
        authMenuItem.action = #selector(loginOrLogout)
        authMenuItem.target = self
        menu.addItem(authMenuItem)
        menu.addItem(NSMenuItem.separatorItem())

        menu.addItem(NSMenuItem.separatorItem())
        let quitMenuItem = menu.addItemWithTitle("Quit", action: #selector(quit), keyEquivalent: "q")
        quitMenuItem?.target = self

        playingImage.template = true
        pauseImage.template   = true

        statusItem.image = pauseImage
        statusItem.menu = menu

        let currentTrack = iTunes.sharedApplication().currentTrack()
        if !(currentTrack.name?.isEmpty ?? true) && !(currentTrack.artist?.isEmpty ?? true) && !(currentTrack.album?.isEmpty ?? true) {
            track = Track(title: currentTrack.name!, artist: currentTrack.artist!, album: currentTrack.album!, storeURL: nil)
            updateSongInfo()
        }

        NSDistributedNotificationCenter.defaultCenter().addObserver(self, selector: #selector(trackChanged(_:)), name: iTunesNotificationName, object: nil)
    }

    deinit {
        NSDistributedNotificationCenter.defaultCenter().removeObserver(self, name: iTunesNotificationName, object: nil)
    }

    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        guard menuItem == songInfoMenuItem else {
            return true
        }
        return track?.storeURL != nil
    }

    func updateSongInfo() {
        guard let track = track else {
            statusItem.title = nil
            statusItem.image = pauseImage
            songInfoMenuItem.hidden = true
            return
        }

        let attributedArtistAlbum = NSAttributedString(string: "\(track.artist) — \(track.album)", attributes: [
            NSForegroundColorAttributeName : NSColor.lightGrayColor(),
        ])
        songInfoMenuItem.attributedTitle = attributedArtistAlbum

        songInfoMenuItem.hidden = false

        // XXX: Hack for item's width
        statusItem.title = " "
        statusItem.title = " " + track.title
        statusItem.image = playingImage
    }

    func trackChanged(notification: NSNotification) {
        if let playerStsate = notification.userInfo?["Player State"] as? String where playerStsate == "Playing" {
            let title  = notification.userInfo?["Name"]   as? String ?? ""
            let artist = notification.userInfo?["Artist"] as? String ?? ""
            let album  = notification.userInfo?["Album"]  as? String ?? ""
            let storeURL = NSURL(string: notification.userInfo?["Store URL"] as? String ?? "")

            track = Track(title: title, artist: artist, album: album, storeURL: storeURL)

            if let storeID = track?.storeID {
                // token は空文字列で送っても問題ない
                let token = NSUserDefaults.standardUserDefaults().stringForKey("token") ?? ""
                let parameters = [ "product_id" : storeID, "token" : token ]
                Alamofire.request(.POST, Endpoint.Listen.URL(), parameters: parameters)
            }
        } else {
            track = nil
        }
        updateSongInfo()
    }

    func openSite() {
        NSWorkspace.sharedWorkspace().openURL(MusicBar.SITE_URL)
    }

    func loginOrLogout() {
        let userDefault = NSUserDefaults.standardUserDefaults()
        if let _ = userDefault.stringForKey("token") {
            userDefault.removeObjectForKey("token")
            updateAuthMenuItem()
        } else {
            let URLComponents = NSURLComponents(URL: MusicBar.SITE_URL, resolvingAgainstBaseURL: false)!
            URLComponents.path = "/login"
            NSWorkspace.sharedWorkspace().openURL(URLComponents.URL!)
        }
    }

    func updateAuthMenuItem() {
        if let _ = NSUserDefaults.standardUserDefaults().stringForKey("token") {
            authMenuItem.title = "ログアウト"
        } else {
            authMenuItem.title = "ログイン"
        }
    }

    func quit() {
        NSApplication.sharedApplication().terminate(self)
    }

    private func openStore(for track: Track) {
        guard let storeURL = track.storeURL else {
            return
        }
        let components = NSURLComponents(string: storeURL.absoluteString)
        components?.scheme = "itmss"
        if let URL = components?.URL {
            NSWorkspace.sharedWorkspace().openURL(URL)
        }
    }
}

