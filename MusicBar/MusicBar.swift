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
    private let songInfoMenuItem  = NSMenuItem()
    private let separatorMenuItem = NSMenuItem.separatorItem()

    private let playingImage = NSImage(named: "playing")!
    private let pauseImage   = NSImage(named: "pause")!

    private var currentTracks: [Track] = []
    // XXX: ちゃんとしたい
    private let currentTrackMenuItems = [
        NSMenuItem(), NSMenuItem(), NSMenuItem(), NSMenuItem(), NSMenuItem()
    ]

    override init() {
        super.init()

        songInfoMenuItem.hidden  = true
        separatorMenuItem.hidden = true

        songInfoMenuItem.target = self
        songInfoMenuItem.action = #selector(openCurrentTrackStore)

        let menu = NSMenu()
        menu.autoenablesItems = true
        menu.addItem(songInfoMenuItem)
        menu.addItem(separatorMenuItem)
        let openSiteMenuItem = menu.addItemWithTitle("サイトをみる", action: #selector(openSite), keyEquivalent: "")

        menu.addItem(NSMenuItem.separatorItem())

        for (index, menuItem) in currentTrackMenuItems.enumerate() {
            menu.addItem(menuItem)
            menuItem.target = self
            menuItem.action = Selector("openStore\(index + 1)")
            menuItem.hidden = true
        }

        openSiteMenuItem?.target = self
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

        // サイトの再生履歴を取得する
        updateRecents()

        NSDistributedNotificationCenter.defaultCenter().addObserver(self, selector: #selector(trackChanged(_:)), name: iTunesNotificationName, object: nil)
    }

    deinit {
        NSDistributedNotificationCenter.defaultCenter().removeObserver(self, name: iTunesNotificationName, object: nil)
    }

    func updateRecents() {
        currentTracks.removeAll()
        currentTrackMenuItems.forEach { $0.hidden = true }

        Alamofire.request(.GET, Endpoint.Recents.URL(), parameters: [ "limit" : currentTrackMenuItems.count + 1 ])
            .responseJSON { [weak self] response in
                switch response.result {
                case .Success(let recents):
                    if let recents = recents as? [[String : String]] {
                        var index = 0
                        for trackInfo in recents {
                            let track = Track(title: trackInfo["track_name"]!, artist: trackInfo["artist_name"]!, album: trackInfo["collection_name"]!, storeURL: NSURL(string: trackInfo["track_view_url"]!)!)

                            if track.title == self?.track?.title {
                                continue
                            }

                            let menuItem = self?.currentTrackMenuItems[index]
                            menuItem?.title = "「\(track.title)」 by \(track.artist)"
                            menuItem?.hidden = false
                            self?.currentTracks.append(track)

                            index += 1

                            if index >= (self?.currentTrackMenuItems.count ?? 0) {
                                break
                            }
                        }
                    }
                case .Failure(let error):
                    print(error)
                }
            }
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
                Alamofire.request(.POST, Endpoint.Listen.URL(), parameters: parameters)
            }
        } else {
            track = nil
        }
        updateSongInfo()
        updateRecents()
    }

    func openCurrentTrackStore() {
        guard let storeURL = track?.storeURL else {
            return
        }
        NSWorkspace.sharedWorkspace().openURL(storeURL)
    }

    func openSite() {
        let siteURL = NSURL(string: "http://music.hacobun.co")!
        NSWorkspace.sharedWorkspace().openURL(siteURL)
    }
    
    func quit() {
        NSApplication.sharedApplication().terminate(self)
    }

    // 最悪

    func openStore1() {
        guard currentTracks.count > 0 else {
            return
        }
        let track = currentTracks[0]
        openStore(for: track)
    }

    func openStore2() {
        guard currentTracks.count > 1 else {
            return
        }
        let track = currentTracks[1]
        openStore(for: track)
    }

    func openStore3() {
        guard currentTracks.count > 2 else {
            return
        }
        let track = currentTracks[2]
        openStore(for: track)
    }

    func openStore4() {
        guard currentTracks.count > 3 else {
            return
        }
        let track = currentTracks[3]
        openStore(for: track)
    }

    func openStore5() {
        guard currentTracks.count > 4 else {
            return
        }
        let track = currentTracks[4]
        openStore(for: track)
    }

    private func openStore(for track: Track) {
        guard let storeURL = track.storeURL else {
            return
        }
        NSWorkspace.sharedWorkspace().openURL(storeURL)
    }
}

