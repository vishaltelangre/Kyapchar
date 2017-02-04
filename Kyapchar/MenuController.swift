//
//  MenuController.swift
//  Kyapchar
//
//  Created by Vishal Telangre on 11/1/16.
//  Copyright © 2016 Vishal Telangre. All rights reserved.
//

import Cocoa

class MenuController: NSObject {
    
    @IBOutlet weak var barMenu: NSMenu!
    @IBOutlet weak var recordStopItem: NSMenuItem!
    @IBOutlet weak var pauseResumeItem: NSMenuItem!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
    
    var recorder: Recorder!
    
    var menubarIconAnimationTimer: Timer?
    var menubarIconCurrentIndex = 0

    @IBAction func onRecordStopItemClick(_ sender: NSMenuItem) {
        if recorder.recording {
            recorder.stop()
            recordStopItem.isEnabled = false
            recordStopItem.title = "Please wait..."
        } else {
           recorder.start()
        }
    }
    
    @IBAction func onPauseResumeItemClick(_ sender: NSMenuItem) {
        if recorder.paused {
            recorder.resume()
        } else {
            recorder.pause()
        }
    }
    
    @IBAction func onQuitItemClick(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
    
    override func awakeFromNib() {
        statusItem.button?.image = NSImage(named: "record")
        
        pauseResumeItem.isEnabled = false
        
        statusItem.menu = barMenu
        recorder = Recorder(delegate: self)
    }
    
    func animateMenubarIcon() {
        menubarIconAnimationTimer = Timer.scheduledTimer(timeInterval: 1/2, target: self, selector: #selector(MenuController.changeMenubarIcon), userInfo: nil, repeats: true)
    }

    func stopMenubarIconAnimation() {
        menubarIconAnimationTimer?.invalidate()
    }

    func changeMenubarIcon() {
        statusItem.button?.image = NSImage(named: NSString(format: "stop-%d", (menubarIconCurrentIndex + 1)) as String)

        menubarIconCurrentIndex += 1

        if menubarIconCurrentIndex > 1 {
            menubarIconCurrentIndex = 0
        }
    }

}

extension MenuController: RecorderDelegate {
    
    func recordingDidStart(_ recordingInfo: RecordingInfo?) {
        recordStopItem.title = "Stop"
        animateMenubarIcon()

        pauseResumeItem.isEnabled = true
        pauseResumeItem.title = "Pause"
    }
    
    func recordingDidStop(_ recordingInfo: RecordingInfo?) {
        recordStopItem.isEnabled = true
        recordStopItem.title = "Record"

        stopMenubarIconAnimation()

        statusItem.button?.image = NSImage(named: "record")
        
        pauseResumeItem.isEnabled = false
        pauseResumeItem.title = "Pause"
        
        recorder = nil
        recorder = Recorder(delegate: self)
        
        if recordingInfo?.location != nil {
            NSWorkspace.shared().activateFileViewerSelecting([recordingInfo!.location as URL])
        }
    }
    
    func recordingDidResume(_ recordingInfo: RecordingInfo?) {
        pauseResumeItem.title = "Pause"
        animateMenubarIcon()
    }
    
    func recordingDidPause(_ recordingInfo: RecordingInfo?) {
        pauseResumeItem.title = "Resume"

        stopMenubarIconAnimation()

        statusItem.button?.image = NSImage(named: "pause")
    }
    
}
