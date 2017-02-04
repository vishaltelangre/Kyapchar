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
    var location: URL
    var duration: Int
    var size: Float
}

protocol RecorderDelegate {
    func recordingDidStart(_ recordingInfo: RecordingInfo?)
    func recordingDidStop(_ recordingInfo: RecordingInfo?)
    func recordingDidResume(_ recordingInfo: RecordingInfo?)
    func recordingDidPause(_ recordingInfo: RecordingInfo?)
}

class Recorder: NSObject {
    
    var delegate: RecorderDelegate?
    
    var session: AVCaptureSession!
    var output: AVCaptureMovieFileOutput!
    var audioRecorder: AVAudioRecorder!
    var castedVideoURL = URL()
    var micAudioURL = URL()
    var finalVideoURL = URL()
    var recordingInfo: RecordingInfo!
    var recording = false
    var paused = false
    
    let micAudioRecordSettings = [AVSampleRateKey : NSNumber(value: Float(44100.0) as Float),
                                  AVFormatIDKey : NSNumber(value: Int32(kAudioFormatMPEG4AAC) as Int32),
                                  AVNumberOfChannelsKey : NSNumber(value: 1 as Int32),
                                  AVEncoderAudioQualityKey : NSNumber(value: Int32(AVAudioQuality.medium.rawValue) as Int32)]
    
    init(delegate: RecorderDelegate) {
        self.delegate = delegate
    }
    
    func start() {
        session = AVCaptureSession()
        output = AVCaptureMovieFileOutput()
        (castedVideoURL, micAudioURL, finalVideoURL) = filePaths()
        
        let input = AVCaptureScreenInput(displayID: CGMainDisplayID())
        let screen = NSScreen.main()!
        let screenRect = screen.frame
        
        do {
            audioRecorder = try AVAudioRecorder(url: micAudioURL, settings: micAudioRecordSettings)
        } catch {
            print("Cannot initialize AVAudioRecorder: \(error)")
            return
        }
        
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        input.cropRect = screenRect
        input?.minFrameDuration = CMTimeMake(1, 1000)
        
        if !session!.canAddInput(input) {
            return
        }
        session!.addInput(input)
        
        if !session!.canAddOutput(output) {
            return
        }
        session!.addOutput(output)
        
        session?.startRunning()
        
        output!.startRecording(toOutputFileURL: castedVideoURL, recordingDelegate: self)
        
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
        if output.isRecording {
            output.pauseRecording()
            paused = true
            delegate?.recordingDidPause(nil)
        }
    }
    
    func resume() {
        if output.isRecordingPaused {
            output.resumeRecording()
            paused = false
            delegate?.recordingDidResume(nil)
        }
    }
    
    func generateFinalVideo() {
        let mixComposition = AVMutableComposition()
        let micAudioAsset = AVAsset(url: micAudioURL)
        let castedVideoAsset = AVAsset(url: castedVideoURL)
        let micAudioTimeRange = CMTimeRangeMake(kCMTimeZero, micAudioAsset.duration)
        let castedVideoTimeRange = CMTimeRangeMake(kCMTimeZero, castedVideoAsset.duration)
        let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do {
            let track: AVAssetTrack = micAudioAsset.tracks(withMediaType: AVMediaTypeAudio).first!
            try compositionAudioTrack.insertTimeRange(micAudioTimeRange, of: track, at: kCMTimeZero)
        } catch {
            print("Error while adding micAudioAsset to compositionAudioTrack: \(error)")
            self.delegate?.recordingDidStop(nil)
        }
        
        do {
            let track: AVAssetTrack = castedVideoAsset.tracks(withMediaType: AVMediaTypeVideo).first!
            try compositionVideoTrack.insertTimeRange(castedVideoTimeRange, of: track, at: kCMTimeZero)
        } catch {
            print("Error while adding castedVideoAsset to compositionVideoTrack: \(error)")
            self.delegate?.recordingDidStop(nil)
        }
        
        let assetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        assetExportSession?.outputFileType = "com.apple.quicktime-movie"
        assetExportSession?.outputURL = finalVideoURL
        assetExportSession?.exportAsynchronously(completionHandler: {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                if assetExportSession?.status == AVAssetExportSessionStatus.completed {
                    var size: Float = 0.0
                    
                    do {
                        let attr : NSDictionary? = try FileManager.default.attributesOfItem(atPath: self.finalVideoURL.path!)
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
                    try FileManager.default.removeItem(at: self.castedVideoURL)
                    try FileManager.default.removeItem(at: self.micAudioURL)
                } catch {
                    print("Error while deleting temporary files: \(error)")
                }
                
                self.delegate?.recordingDidStop(self.recordingInfo)
            })
        })
    }
    
    func filePaths() -> (URL, URL, URL) {
        let date = Date()
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components([.hour, .minute, .second, .day, .month, .year], from: date)
        let moviesDirectoryURL: URL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        let finalVideoFilename = "Kyapchar_\(components.day)-\(components.month)-\(components.year)_\(components.hour):\(components.minute):\(components.second).mov"
        let finalVideoPath = moviesDirectoryURL.appendingPathComponent(finalVideoFilename)
        let filename = date.timeIntervalSince1970 * 1000
        let tempVideoFilePath = URL(fileURLWithPath: "/tmp/\(filename).mp4")
        let tempMicAudioFilePath = URL(fileURLWithPath: "/tmp/\(filename).m4a")
        
        return (tempVideoFilePath, tempMicAudioFilePath, finalVideoPath)
    }
}

extension Recorder: AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didPauseRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        audioRecorder.pause()
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didResumeRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        audioRecorder.record()
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        audioRecorder.record()
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        if (error != nil) {
            debugPrint(error)
            return
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            self.session?.stopRunning()
            self.audioRecorder?.stop()
            
            self.generateFinalVideo()
            
            self.session = nil
            self.output = nil
            self.audioRecorder = nil
        }
    }
}
