//
//  Recorder.swift
//  Kyapchar
//
//  Created by Vishal Telangre on 11/1/16.
//  Copyright © 2016 Vishal Telangre. All rights reserved.
//

import Foundation
import AVFoundation

struct RecordingInfo {
    var location: NSURL
    var duration: Int
    var size: Float
}

protocol RecorderDelegate {
    func recordingDidStart(recordingInfo: RecordingInfo?)
    func recordingDidStop(recordingInfo: RecordingInfo?)
    func recordingDidResume(recordingInfo: RecordingInfo?)
    func recordingDidPause(recordingInfo: RecordingInfo?)
}

class Recorder: NSObject {
    
    var delegate: RecorderDelegate?
    
    var session: AVCaptureSession!
    var output: AVCaptureMovieFileOutput!
    var audioRecorder: AVAudioRecorder!
    var castedVideoURL = NSURL()
    var micAudioURL = NSURL()
    var finalVideoURL = NSURL()
    var recordingInfo: RecordingInfo!
    var recording = false
    var paused = false
    
    let micAudioRecordSettings = [AVSampleRateKey : NSNumber(float: Float(44100.0)),
                                  AVFormatIDKey : NSNumber(int: Int32(kAudioFormatMPEG4AAC)),
                                  AVNumberOfChannelsKey : NSNumber(int: 1),
                                  AVEncoderAudioQualityKey : NSNumber(int: Int32(AVAudioQuality.Medium.rawValue))]
    
    init(delegate: RecorderDelegate) {
        self.delegate = delegate
    }
    
    func start() {
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
            return
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
        
        recording = true
        delegate?.recordingDidStart(nil)
    }
    
    func stop() {
        if output != nil {
            recording = false
            output?.stopRecording()
        }
    }
    
    func pause() {
        if output.recording {
            output.pauseRecording()
            paused = true
            delegate?.recordingDidPause(nil)
        }
    }
    
    func resume() {
        if output.recordingPaused {
            output.resumeRecording()
            paused = false
            delegate?.recordingDidResume(nil)
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
            self.delegate?.recordingDidStop(nil)
        }
        
        do {
            let track: AVAssetTrack = castedVideoAsset.tracksWithMediaType(AVMediaTypeVideo).first!
            try compositionVideoTrack.insertTimeRange(castedVideoTimeRange, ofTrack: track, atTime: kCMTimeZero)
        } catch {
            print("Error while adding castedVideoAsset to compositionVideoTrack: \(error)")
            self.delegate?.recordingDidStop(nil)
        }
        
        let assetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        assetExportSession?.outputFileType = "com.apple.quicktime-movie"
        assetExportSession?.outputURL = finalVideoURL
        assetExportSession?.exportAsynchronouslyWithCompletionHandler({
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
                if assetExportSession?.status == AVAssetExportSessionStatus.Completed {
                    var size: Float = 0.0
                    
                    do {
                        let attr : NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(self.finalVideoURL.path!)
                        if let _attr = attr {
                            size = Float(_attr.fileSize()/(1024*1024));
                        }
                    } catch {
                        print("Error while fetching final video file size: \(error)")
                    }
                    
                    let duration = Int(CMTimeGetSeconds((assetExportSession?.asset.duration)!))
                    let location = self.finalVideoURL
                    self.recordingInfo = RecordingInfo(location: location, duration: duration, size: size)
                    
                } else {
                    print("Export failed")
                    self.recordingInfo = nil
                }
                
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(self.castedVideoURL)
                    try NSFileManager.defaultManager().removeItemAtURL(self.micAudioURL)
                } catch {
                    print("Error while deleting temporary files: \(error)")
                }
                
                self.delegate?.recordingDidStop(self.recordingInfo)
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
        
        return (tempVideoFilePath, tempMicAudioFilePath, finalVideoPath)
    }
}

extension Recorder: AVCaptureFileOutputRecordingDelegate {
    func captureOutput(captureOutput: AVCaptureFileOutput!, didPauseRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        audioRecorder.pause()
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didResumeRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        audioRecorder.record()
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        audioRecorder.record()
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        if (error != nil) {
            debugPrint(error)
            return
        }
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            self.session?.stopRunning()
            self.audioRecorder?.stop()
            
            self.generateFinalVideo()
            
            self.session = nil
            self.output = nil
            self.audioRecorder = nil
        }
    }
}
