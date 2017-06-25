
//
//  LaunchAtLoginHelper.swift
//
//  Created by Erica Sadun on 4/1/15.
//  Copyright (c) 2015 Erica Sadun. All rights reserved.
//
//  Modified by Vishal Telangre on 06/25/2017.
//  Copyright (c) 2017 Vishal Telangre. All rights reserved.
//

import Foundation

class LaunchAtLoginHelper {
    static func getLoginItems() -> LSSharedFileList? {
        let allocator : CFAllocator! = CFAllocatorGetDefault().takeUnretainedValue()
        let kLoginItems : CFString! = kLSSharedFileListSessionLoginItems.takeUnretainedValue()
        let loginItems_ = LSSharedFileListCreate(allocator, kLoginItems, nil)
        if loginItems_ == nil {return nil}
        let loginItems : LSSharedFileList! = loginItems_!.takeRetainedValue()
        return loginItems
    }
    
    static func existingItem(itemURL : NSURL) -> LSSharedFileListItem? {
        let loginItems_ = getLoginItems()
        if loginItems_ == nil {return nil}
        let loginItems = loginItems_!
        
        var seed : UInt32 = 0
        let currentItems = LSSharedFileListCopySnapshot(loginItems, &seed).takeRetainedValue() as? NSArray
        
        if currentItems == nil {
            return nil
        }
        
        for item in currentItems! {
            let resolutionFlags : UInt32 = UInt32(kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes)
            if item != nil {
                let unmanagedUrlRef = LSSharedFileListItemCopyResolvedURL(item as! LSSharedFileListItem, resolutionFlags, nil)
                if unmanagedUrlRef != nil {
                    if let url = unmanagedUrlRef?.takeRetainedValue() as? NSURL {
                        if url.isEqual(itemURL) {
                            let result = item as! LSSharedFileListItem
                            return result
                        }
                    }
                }

            }
        }
        
        return nil
    }
    
    static func willLaunchAtLogin(itemURL : NSURL) -> Bool {
        return existingItem(itemURL: itemURL) != nil
    }
    
    static func setLaunchAtLogin(itemURL: NSURL, enabled: Bool) -> Bool {
        let loginItems_ = getLoginItems()
        if loginItems_ == nil {
            return false
        }
        let loginItems = loginItems_!
        
        let item = existingItem(itemURL: itemURL)
        if item != nil && enabled {
            return true
        }
        if item != nil && !enabled {
            LSSharedFileListItemRemove(loginItems, item)
            return true
        }
        
        LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst.takeUnretainedValue(), nil, nil, itemURL as CFURL, nil, nil)
        return true
    }
}
