//
//  AudioRecordingViewModel.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//

import Foundation
import AVFoundation
import SwiftUI

class AudioRecordingViewModel: ObservableObject {
    @Published var audioRecordings: [AudioRecording] = []
    @Published var hasPermission = false
    @Published var showingPermissionAlert = false {
        didSet {
            print("DEBUG: showingPermissionAlert changed to \(showingPermissionAlert)")
        }
    }
    @Published var isRecording: Bool = false
    private var audioRecorder: AVAudioRecorder?
    
    private var recordingSession: AVAudioSession?
    private let isPreview: Bool
    
    // Computed properties for backward compatibility with views
    var audioFiles: [URL] {
        return audioRecordings.map { $0.url }
    }
    
    var audioFileNames: [String] {
        return audioRecordings.map { $0.fileName }
    }
    
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        
        // Set up mock data for previews
        if isPreview {
            self.hasPermission = true
            self.audioRecordings = [
                AudioRecording(url: URL(fileURLWithPath: "/mock/path/Recording_001.m4a")),
                AudioRecording(url: URL(fileURLWithPath: "/mock/path/Recording_002.m4a")),
                AudioRecording(url: URL(fileURLWithPath: "/mock/path/Recording_003.m4a"))
            ]
        }
    }
    
    func initialize() {
        // Skip initialization for previews since they use mock data
        if isPreview {
            return
        }
        
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            self.hasPermission = true
        } else {
            requestPermission()
            refreshAudioFiles()
        }
    }
    
    func requestPermission() {
        // Skip for previews
        guard !isPreview else { return }
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.configureAudioSession()
                    } else {
                        print("Microphone permission was denied.")
                        self.hasPermission = false
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showingPermissionAlert = true
                        }
                    }
                }
            }
        } else {
            // Fallback for earlier versions
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.configureAudioSession()
                    } else {
                        print("Microphone permission was denied.")
                        self.hasPermission = false
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showingPermissionAlert = true
                        }
                    }
                }
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            let recordingSession = AVAudioSession.sharedInstance()
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            self.hasPermission = true
            print("Microphone permission granted.")
            
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
            self.hasPermission = false
        }
    }
    
    func refreshAudioFiles() {
        // Skip for previews since they use mock data
        guard !isPreview else { return }
        
        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            print("DEBUG: Documents directory: \(url)")
            
            let result = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: .producesRelativePathURLs
            )
            print("DEBUG: Found \(result.count) files in documents directory")
            
            // Clear the array first, then populate it
            self.audioRecordings.removeAll()
            
            for fileURL in result {
                print("DEBUG: Found file: \(fileURL.lastPathComponent) with extension: \(fileURL.pathExtension)")
                // Only add audio files
                if fileURL.pathExtension.lowercased() == "m4a" {
                    let audioRecording = AudioRecording(url: fileURL)
                    self.audioRecordings.append(audioRecording)
                    print("DEBUG: Added audio file: \(audioRecording.fileName)")
                }
            }
            
            print("DEBUG: Total audio files: \(audioRecordings.count)")
            
        } catch {
            print("DEBUG: Error reading directory: \(error.localizedDescription)")
        }
    }
    
    
    func startRecording() {
            let recordingSession = AVAudioSession.sharedInstance()
            
            do {
                try recordingSession.setActive(true)
            } catch {
                print("Failed to activate session: \(error.localizedDescription)")
                return
            }

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let audioFilename = documentsPath.appendingPathComponent("Recording_\(dateFormatter.string(from: Date())).m4a")

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            do {
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                audioRecorder?.record()
                
                DispatchQueue.main.async {
                    self.isRecording = true
                }
                print("DEBUG: Started recording to \(audioFilename)")
            } catch {
                print("Could not start recording: \(error.localizedDescription)")
                stopRecording() // Clean up
            }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Refresh file list to make the new recording appear
        refreshAudioFiles()
        
        print("DEBUG: Stopped recording.")
    }
    
//    func deleteRecording(recording: AudioRecording) {
//        do {
//            try FileManager.default.removeItem(at: recording.url)
//        } catch {
//            print("Error deleting the file: \(error)")
//        }
//        
//        audioRecordings.removeAll { currentRecording in
//            return currentRecording.id == recording.id
//        }
//    }
    
    func delete(at offsets: IndexSet) {
        let recordingsToDelete = offsets.map { (position) in
            return self.audioRecordings[position]
        }
        // offsets.map { self.audioRecordings[$0] }
        
        for recording in recordingsToDelete {
            do {
                try FileManager.default.removeItem(at: recording.url)
            } catch {
                print("Error deleting the file: \(error)")
            }
        }
        
        audioRecordings.remove(atOffsets: offsets)
    }
    
    
    
}




extension AudioRecordingViewModel {
    static func mockViewModel() -> AudioRecordingViewModel {
        return AudioRecordingViewModel(isPreview: true)
    }
}



