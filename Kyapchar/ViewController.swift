//
//  ViewController.swift
//  Kyapchar
//
//  Created by Vishal Telangre on 10/1/16.
//  Copyright © 2016 Vishal Telangre. All rights reserved.
//

import Cocoa
import AVFoundation
import AppKit

class ViewController: NSViewController, AVCaptureFileOutputRecordingDelegate {
    var session: AVCaptureSession? = AVCaptureSession()
    var output: AVCaptureMovieFileOutput? = AVCaptureMovieFileOutput()
    
    @IBOutlet weak var recordButton: NSButton!
    @IBOutlet weak var durationLabel: NSTextField!
    
    @IBAction func onRecordClick(sender: NSButton) {
        if (sender.state == NSOffState) {
            sender.title = "▶️"
            stopRecording()
        } else {
            sender.title = "🔴"
            durationLabel.stringValue = ""
            startRecording()
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        recordButton.setNextState()
    }
    
    func startRecording() {
        if session == nil {
            session = AVCaptureSession()
        }
        
        if output == nil {
            output = AVCaptureMovieFileOutput()
        }
        
        let input = AVCaptureScreenInput(displayID: CGMainDisplayID())
        let screen = NSScreen.mainScreen()!
        let screenRect = screen.frame
        let destination: NSURL = unqiueDestination()
        
        input.cropRect = screenRect
        input.minFrameDuration = CMTimeMake(1, 1000)
        
        if !session!.canAddInput(input) {
            return
        }
        session!.addInput(input)
        
        if !session!.canAddOutput(output) {
            return
        }
        session!.addOutput(output)
        
        session?.startRunning()
        
        do {
            try NSFileManager.defaultManager().removeItemAtURL(destination)
        } catch {
            print("Error while deleting file: \(error)")
        }
        
        output!.startRecordingToOutputFileURL(destination, recordingDelegate: self)
    }
    
    func stopRecording() {
        if output != nil {
            output!.stopRecording()
            let duration: Int = Int(CMTimeGetSeconds(output!.recordedDuration))
            let location = output!.outputFileURL.absoluteString
            var fileSize : Float = 0.0
            
            do {
                let attr : NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(output!.outputFileURL.path!)
                if let _attr = attr {
                    fileSize = Float(_attr.fileSize()/(1024*1024));
                }
            } catch {
                print("Error while fetching recorded file size: \(error)")
            }
            
            durationLabel.stringValue = "⌚ \(formatDuration(duration)) Seconds\n📁 \(location)\nSize \(String(format: "%.2f", fileSize)) MB"
        }
    }

    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        if (error != nil) {
            debugPrint(error)
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            self.session?.stopRunning()
            self.session = nil
            self.output = nil
        }
    }
    
    func unqiueDestination() -> NSURL {
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Hour, .Minute, .Second, .Day, .Month, .Year], fromDate: date)
        let moviesDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.MoviesDirectory, inDomains: .UserDomainMask)[0]
        let fileName = "Kyapchar_\(components.day)-\(components.month)-\(components.year)_\(components.hour):\(components.minute):\(components.second).mov"
        
        return moviesDirectoryURL.URLByAppendingPathComponent(fileName)
    }
    
    func formatDuration(seconds: Int) -> String {
        let hrs: Int = Int(seconds / 3600)
        let mins: Int = Int((seconds % 3600) / 60)
        let secs: Int = Int((seconds % 3600) % 60)
        
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
}
