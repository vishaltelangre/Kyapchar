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
    var session: AVCaptureSession!
    var output: AVCaptureMovieFileOutput!
    var audioRecorder: AVAudioRecorder!
    var castedVideoURL = NSURL()
    var micAudioURL = NSURL()
    var finalVideoURL = NSURL()
    
    let micAudioRecordSettings = [AVSampleRateKey : NSNumber(float: Float(44100.0)),
                          AVFormatIDKey : NSNumber(int: Int32(kAudioFormatMPEG4AAC)),
                          AVNumberOfChannelsKey : NSNumber(int: 1),
                          AVEncoderAudioQualityKey : NSNumber(int: Int32(AVAudioQuality.Medium.rawValue))]
    
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
        session = AVCaptureSession()
        output = AVCaptureMovieFileOutput()
        (castedVideoURL, micAudioURL, finalVideoURL) = filePaths()
        
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
            output!.stopRecording()
            audioRecorder?.stop()
            durationLabel.stringValue = "Please wait..."
        }
    }

    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        if (error != nil) {
            debugPrint(error)
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            self.session?.stopRunning()
            
            self.generateFinalVideo()
            
            self.session = nil
            self.output = nil
            self.audioRecorder = nil
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
            dispatch_async(dispatch_get_main_queue(), { 
                if assetExportSession!.status == AVAssetExportSessionStatus.Completed {
                    let duration: Int = Int(CMTimeGetSeconds(castedVideoAsset.duration))
                    var fileSize : Float = 0.0
                    
                    do {
                        let attr : NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(self.finalVideoURL.path!)
                        if let _attr = attr {
                            fileSize = Float(_attr.fileSize()/(1024*1024));
                        }
                    } catch {
                        print("Error while fetching final video file size: \(error)")
                    }
                    
             
                    self.durationLabel.stringValue = "⌚ \(self.formatDuration(duration)) Seconds\n📁 \(self.finalVideoURL.absoluteString)\nSize \(String(format: "%.2f", fileSize)) MB"
                } else {
                    print("Export failed")
                    self.durationLabel.stringValue = "Export failed!"
                }
                
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(self.castedVideoURL)
                    try NSFileManager.defaultManager().removeItemAtURL(self.micAudioURL)
                } catch {
                    print("Error while deleting temporary files: \(error)")
                }

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
