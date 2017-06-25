//
//  Preferences.swift
//  Kyapchar
//
//  Created by Vishal Telangre on 6/23/17.
//  Copyright © 2017 Vishal Telangre. All rights reserved.
//

import Cocoa
import ServiceManagement

class Preferences: NSWindowController {
    @IBOutlet weak var saveLocationLabel: NSTextField!
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var launchAtLoginCheckbox: NSButton!
    
    let appURL = NSURL(fileURLWithPath: Bundle.main.bundlePath)
    
    @IBAction func onSaveLocationChangeClick(_ sender: NSButton) {
        let dialog = NSOpenPanel();
        dialog.title = "Choose location where recorded videos should be saved"
        dialog.directoryURL = UserDefaults.standard.url(forKey: "KyapcharSaveLocation")
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.canChooseDirectories = true;
        dialog.canChooseFiles = false;
        dialog.canCreateDirectories = true;
        dialog.allowsMultipleSelection = false;
        
        if (dialog.runModal() == NSModalResponseOK) {
            let result = dialog.url
            
            if (result != nil) {
                UserDefaults.standard.set(dialog.url, forKey: "KyapcharSaveLocation")
                saveLocationLabel.stringValue = result!.path
                saveLocationLabel.toolTip = result!.path
            }
        }
    }
    
    @IBAction func onLaunchAtLoginClick(_ sender: NSButton) {
        let autoLaunch = launchAtLoginCheckbox.state == NSOnState
        if LaunchAtLoginHelper.setLaunchAtLogin(itemURL: appURL, enabled: autoLaunch) {
            if autoLaunch {
                NSLog("Successfully added as a login item")
            } else {
                NSLog("Successfully removed as a login item")
            }
        } else {
            NSLog("Failed to add as a login item")
        }
    }
    
    @IBAction func onGithubLinkClick(_ sender: NSButton) {
        NSWorkspace.shared().open(URL(string: sender.title)!)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        versionLabel.stringValue = "Build v\(version)"
        
        let configuredSaveLocation = UserDefaults.standard.url(forKey: "KyapcharSaveLocation")
        saveLocationLabel.stringValue = configuredSaveLocation!.path
        saveLocationLabel.toolTip = configuredSaveLocation!.path
        
        launchAtLoginCheckbox.state = LaunchAtLoginHelper.willLaunchAtLogin(itemURL: appURL) ? NSOnState : NSOffState
        NSApp.activate(ignoringOtherApps: true)
    }
    
}
