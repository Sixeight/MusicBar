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

    private var track: Track?

    private let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    private let songInfoMenuItem  = NSMenuItem()
    private let separatorMenuItem = NSMenuItem.separatorItem()

    private let playingImage = NSImage(named: "playing")!
    private let pauseImage   = NSImage(named: "pause")!

    override init() {
        super.init()

        songInfoMenuItem.hidden  = true
        separatorMenuItem.hidden = true

        songInfoMenuItem.target = self
        songInfoMenuItem.action = #selector(openStore)

        let menu = NSMenu()
        menu.autoenablesItems = true
        menu.addItem(songInfoMenuItem)
        menu.addItem(separatorMenuItem)
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
            songInfoMenuItem.hidden  = true
            separatorMenuItem.hidden = true
            return
        }

        let attributedArtistAlbum = NSAttributedString(string: "\(track.artist) — \(track.album)", attributes: [
            NSForegroundColorAttributeName : NSColor.lightGrayColor(),
        ])
        songInfoMenuItem.attributedTitle = attributedArtistAlbum

        songInfoMenuItem.hidden  = false
        separatorMenuItem.hidden = false

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
                let parameters = [ "product_id" : storeID ]
                Alamofire.request(.POST, "http://localhost:4567/listen", parameters: parameters)
            }

        } else {
            track = nil
        }
        updateSongInfo()
    }

    func openStore() {
        guard let storeURL = track?.storeURL else {
            return
        }
        NSWorkspace.sharedWorkspace().openURL(storeURL)
    }
    
    func quit() {
        NSApplication.sharedApplication().terminate(self)
    }
}

