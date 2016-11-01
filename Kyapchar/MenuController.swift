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
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
    
    var recorder: Recorder!
    
    @IBAction func onRecordStopItemClick(sender: NSMenuItem) {
        if recorder.recording {
            recorder.stop()
            recordStopItem.enabled = false
            recordStopItem.title = "Please wait..."
        } else {
           recorder.start()
        }
    }
    
    @IBAction func onPauseResumeItemClick(sender: NSMenuItem) {
        if recorder.paused {
            recorder.resume()
        } else {
            recorder.pause()
        }
    }
    
    @IBAction func onQuitItemClick(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    override func awakeFromNib() {
        statusItem.button?.image = NSImage(named: "record")
        
        pauseResumeItem.enabled = false
        
        statusItem.menu = barMenu
        recorder = Recorder(delegate: self)
    }
    
}

extension MenuController: RecorderDelegate {
    
    func recordingDidStart(recordingInfo: RecordingInfo?) {
        recordStopItem.title = "Stop"
        statusItem.button?.image = NSImage(named: "stop")
        
        pauseResumeItem.enabled = true
        pauseResumeItem.title = "Pause"
    }
    
    func recordingDidStop(recordingInfo: RecordingInfo?) {
        recordStopItem.enabled = true
        recordStopItem.title = "Record"
        statusItem.button?.image = NSImage(named: "record")
        
        pauseResumeItem.enabled = false
        pauseResumeItem.title = "Pause"
        
        recorder = nil
        recorder = Recorder(delegate: self)
        
        if recordingInfo?.location != nil {
            NSWorkspace.sharedWorkspace().activateFileViewerSelectingURLs([recordingInfo!.location])
        }
    }
    
    func recordingDidResume(recordingInfo: RecordingInfo?) {
        pauseResumeItem.title = "Pause"
        statusItem.button?.image = NSImage(named: "stop")
    }
    
    func recordingDidPause(recordingInfo: RecordingInfo?) {
        pauseResumeItem.title = "Resume"
        statusItem.button?.image = NSImage(named: "pause")
    }
    
}