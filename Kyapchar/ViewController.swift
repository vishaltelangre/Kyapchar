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

class ViewController: NSViewController, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var session: AVCaptureSession? = AVCaptureSession()
    var output: AVCaptureMovieFileOutput? = AVCaptureMovieFileOutput()
    
    @IBOutlet weak var recordButton: NSButton!
    @IBOutlet weak var durationLabel: NSTextField!
    
    @IBAction func onRecordClick(sender: NSButton) {
        if (sender.state == NSOffState) {
            sender.title = "Record"
            stopRecording()
        } else {
            sender.title = "Stop"
            durationLabel.stringValue = ""
            startRecording()
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        recordButton.setNextState()
    }
    
    func startRecording() {
        if session == nil || output == nil {
            return
        }
        
        let displayID = CGMainDisplayID()
        let input = AVCaptureScreenInput(displayID: displayID)
        let screen = NSScreen.mainScreen()!
        let screenRect = screen.frame
        let destination = NSURL(fileURLWithPath: "/tmp/test.mov")
        
        input.cropRect = screenRect
        input.minFrameDuration = refreshRateForDisplay(displayID)
        
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
        } catch _ {}
        
        output!.startRecordingToOutputFileURL(destination, recordingDelegate: self)
    }
    
    func stopRecording() {
        if output != nil {
            output!.stopRecording()
            durationLabel.stringValue = "Duration: \(CMTimeGetSeconds(output!.recordedDuration)) | Location: \(output!.outputFileURL.absoluteString)"
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
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        durationLabel.stringValue = "Duration: \(CMTimeGetSeconds(output!.recordedDuration))"
    }
    
    func refreshRateForDisplay(displayID: CGDirectDisplayID) -> CMTime {
        // TODO
        return CMTimeMake(1, 1000)
    }
}
