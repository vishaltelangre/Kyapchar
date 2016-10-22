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

class ViewController: NSViewController {
    var session: AVCaptureSession!
    var output: AVCaptureMovieFileOutput!
    var audioRecorder: AVAudioRecorder!
    var castedVideoURL = NSURL()
    var micAudioURL = NSURL()
    var finalVideoURL = NSURL()
    var storedFileInfo: [[String]] = []
    
    let micAudioRecordSettings = [AVSampleRateKey : NSNumber(float: Float(44100.0)),
                          AVFormatIDKey : NSNumber(int: Int32(kAudioFormatMPEG4AAC)),
                          AVNumberOfChannelsKey : NSNumber(int: 1),
                          AVEncoderAudioQualityKey : NSNumber(int: Int32(AVAudioQuality.Medium.rawValue))]
    
    @IBOutlet weak var recordButton: NSButton!
    @IBOutlet weak var debugInfoLabel: NSTextField!
    @IBOutlet weak var pauseResumeButton: NSButton!
    @IBOutlet weak var storedFileInfoTableView: NSTableView!
    
    @IBAction func onRecordClick(sender: NSButton) {
        if (sender.state == NSOffState) {
            sender.image = NSImage(named: "record")
            sender.toolTip = "Start Recording"
            pauseResumeButton.hidden = true
            stopRecording()
        } else {
            sender.image = NSImage(named: "stop")
            sender.toolTip = "Stop Recording"
            pauseResumeButton.hidden = false
            debugInfoLabel.stringValue = ""
            startRecording()
        }
    }
    
    @IBAction func onPauseResumeClick(sender: NSButton) {
        if output.recordingPaused {
            output.resumeRecording()
            audioRecorder.record()
        } else {
            output.pauseRecording()
            audioRecorder.pause()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        pauseResumeButton.hidden = true
        pauseResumeButton.image = NSImage(named: "pause")
        pauseResumeButton.toolTip = "Pause Recording"

        storedFileInfoTableView.setDataSource(self)
    }
    
    func startRecording() {
        storedFileInfo = []
        session = AVCaptureSession()
        output = AVCaptureMovieFileOutput()
        (castedVideoURL, micAudioURL, finalVideoURL) = filePaths()
        storedFileInfoTableView.reloadData()
        
        let input = AVCaptureScreenInput(displayID: CGMainDisplayID())
        let screen = NSScreen.mainScreen()!
        let screenRect = screen.frame
        
        do {
            audioRecorder = try AVAudioRecorder(URL: micAudioURL, settings: micAudioRecordSettings)
        } catch {
            print("Cannot initialize AVAudioRecorder: \(error)")
        }
        
        audioRecorder?.meteringEnabled = true
        audioRecorder?.prepareToRecord()
        
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
        
        output!.startRecordingToOutputFileURL(castedVideoURL, recordingDelegate: self)
        audioRecorder.record()
    }
    
    func stopRecording() {
        if output != nil {
            output?.stopRecording()
            audioRecorder?.stop()
            debugInfoLabel.stringValue = "Please wait..."
        }
    }
    
    func generateFinalVideo() {
        let mixComposition = AVMutableComposition()
        let micAudioAsset = AVAsset(URL: micAudioURL)
        let castedVideoAsset = AVAsset(URL: castedVideoURL)
        let micAudioTimeRange = CMTimeRangeMake(kCMTimeZero, micAudioAsset.duration)
        let castedVideoTimeRange = CMTimeRangeMake(kCMTimeZero, castedVideoAsset.duration)
        let compositionAudioTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionVideoTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do {
            let track: AVAssetTrack = micAudioAsset.tracksWithMediaType(AVMediaTypeAudio).first!
            try compositionAudioTrack.insertTimeRange(micAudioTimeRange, ofTrack: track, atTime: kCMTimeZero)
        } catch {
            print("Error while adding micAudioAsset to compositionAudioTrack: \(error)")
        }
        
        do {
            let track: AVAssetTrack = castedVideoAsset.tracksWithMediaType(AVMediaTypeVideo).first!
            try compositionVideoTrack.insertTimeRange(castedVideoTimeRange, ofTrack: track, atTime: kCMTimeZero)
        } catch {
            print("Error while adding castedVideoAsset to compositionVideoTrack: \(error)")
        }
        
        let assetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        assetExportSession?.outputFileType = "com.apple.quicktime-movie"
        assetExportSession?.outputURL = finalVideoURL
        assetExportSession?.exportAsynchronouslyWithCompletionHandler({
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
                if assetExportSession?.status == AVAssetExportSessionStatus.Completed {
                    let duration: Int = Int(CMTimeGetSeconds((assetExportSession?.asset.duration)!))
                    var fileSize : Float = 0.0
                    
                    do {
                        let attr : NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(self.finalVideoURL.path!)
                        if let _attr = attr {
                            fileSize = Float(_attr.fileSize()/(1024*1024));
                        }
                    } catch {
                        print("Error while fetching final video file size: \(error)")
                    }
                    
                    self.storedFileInfo = [["Duration", "\(self.formatDuration(duration)) Seconds"],
                                           ["Location", self.finalVideoURL.absoluteString.stringByReplacingOccurrencesOfString("file://" + NSHomeDirectory(), withString: "~")],
                                            ["Size", "\(String(format: "%.2f", fileSize)) MB"]]
                } else {
                    print("Export failed")
                    self.storedFileInfo = [["Error", "Export Failed"]]
                }
                
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(self.castedVideoURL)
                    try NSFileManager.defaultManager().removeItemAtURL(self.micAudioURL)
                } catch {
                    print("Error while deleting temporary files: \(error)")
                }

                dispatch_async(dispatch_get_main_queue(), {
                    self.debugInfoLabel.stringValue = ""
                    self.storedFileInfoTableView.reloadData()
                })
            })
        })
    }
    
    func filePaths() -> (NSURL, NSURL, NSURL) {
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Hour, .Minute, .Second, .Day, .Month, .Year], fromDate: date)
        let moviesDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.MoviesDirectory, inDomains: .UserDomainMask)[0]
        let finalVideoFilename = "Kyapchar_\(components.day)-\(components.month)-\(components.year)_\(components.hour):\(components.minute):\(components.second).mov"
        let finalVideoPath = moviesDirectoryURL.URLByAppendingPathComponent(finalVideoFilename)
        let filename = date.timeIntervalSince1970 * 1000
        let tempVideoFilePath = NSURL(fileURLWithPath: "/tmp/\(filename).mp4")
        let tempMicAudioFilePath = NSURL(fileURLWithPath: "/tmp/\(filename).m4a")
        
        print("Paths: tempVideoFilePath: \(tempVideoFilePath), tempMicAudioFilePath: \(tempMicAudioFilePath), finalVideoPath: \(finalVideoPath)")
        
        return (tempVideoFilePath, tempMicAudioFilePath, finalVideoPath)
    }
    
    func formatDuration(seconds: Int) -> String {
        let hrs: Int = Int(seconds / 3600)
        let mins: Int = Int((seconds % 3600) / 60)
        let secs: Int = Int((seconds % 3600) % 60)
        
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func captureOutput(captureOutput: AVCaptureFileOutput!, didPauseRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        pauseResumeButton.image = NSImage(named: "resume")
        pauseResumeButton.toolTip = "Resume Recording"
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didResumeRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        pauseResumeButton.image = NSImage(named: "pause")
        pauseResumeButton.toolTip = "Pause Recording"
        
        NSApp.mainWindow?.miniaturize(self)
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        NSApp.mainWindow?.miniaturize(self)
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        if (error != nil) {
            debugPrint(error)
        }
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            self.session?.stopRunning()
            
            self.generateFinalVideo()
            
            self.session = nil
            self.output = nil
            self.audioRecorder = nil
        }
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return storedFileInfo.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let item = storedFileInfo[row]
        
        if tableColumn?.identifier == "key" {
            return item[0]
        } else {
            return item[1]
        }
    }
}