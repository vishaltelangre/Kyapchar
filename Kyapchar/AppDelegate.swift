//
//  AppDelegate.swift
//  Kyapchar
//
//  Created by Vishal Telangre on 10/31/16.
//  Copyright © 2016 Vishal Telangre. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let configuredSaveLocation = UserDefaults.standard.url(forKey: "KyapcharSaveLocation")
        let defaultSaveLocation = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        
        if (configuredSaveLocation == nil) {
            UserDefaults.standard.set(defaultSaveLocation, forKey: "KyapcharSaveLocation")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

