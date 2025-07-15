//
//  AudioRecordingViewModel.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

/// The central coordinator for the audio recording UI.
///
/// This ViewModel acts as a "manager" that owns and delegates tasks to specialist services
/// for file management, session configuration, and recording. It listens for state changes
/// from these services and publishes them for the SwiftUI views to observe.
class AudioRecordingViewModel: ObservableObject {
    
    // MARK: - Services
    
    /// The service that handles all audio file operations.
    private let fileService: AudioFileService
    
    /// The service that handles all `AVAudioSession` configuration and permissions.
    private let audioSessionService: AudioSessionService
    
    /// The service that handles the actual recording process.
    private let recordingService: RecordingService
    
    // MARK: - @Published UI State
    
    /// The list of all audio recordings. This property is the main data source for the UI's list view.
    @Published var audioRecordings: [AudioRecording] = []
    
    /// A Boolean indicating if the app has been granted microphone permission.
    @Published var hasPermission = false
    
    /// Controls the presentation of the alert show to the user when microphone permission has been denied.
    @Published var showingPermissionAlert = false
    
    /// The current recording state of the app. This drive the UI of the record button and the timer.
    @Published var isRecording: Bool = false
        
    /// A Boolean indicating if mulichannel recording mode is on, controlled by the toggle in Settings.
    @Published var isMultichannelMode: Bool = false {
        didSet {
            // When this property changes, give a command to the service
            audioSessionService.configureAudioSession(isMultichannel: isMultichannelMode)
        }
    }
    
    /// An array of Booleans to track which channel toggles are enabled in the UI.
    @Published var enabledChannels: [Bool] = []
    
    /// An array that contains the gain levels for each active audio channel.
    @Published var channelGainLevels: [Float] = []
    
    /// The number of active input channels, mirrored from the `AudioSessionService`.
    @Published var availableChannels: Int = 0
    
    /// The maximum number of input channels the hardware supports, mirrored from the `AudioSessionService`.
    @Published var maxChannels: Int = 0
    
    /// The display name of the current audio input, mirrored from the `AudioSessionService`.
    @Published var currentInputSource: String = "Unknown"
    
    /// The names of the active channels, mirrored from the `AudioSessionService`.
    @Published var channelNames: [String] = []

    /// The names of all discoverable audio inputs, mirrored from the `AudioSessionService`.
    @Published var availableInputNames: [String] = []
    
    // MARK: - Internal State
    
    /// A Boolean that is true when the ViewModel is instantiated for SwiftUI's Previews, used to load mock data.
    private let isPreview: Bool
    
    /// Set to store Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// A computed property that returns an array of just the URLs from the `audioRecordings` array.
    /// Useful for views that only need the file paths.
    var audioFiles: [URL] {
        // Return each AudioRecording object and extract just its url
        return audioRecordings.map { $0.url }
    }
    
    /// A computed property that returns an array of just the file names from the `audioRecordings` array.
    var audioFileNames: [String] {
        // Return each AudioRecording object and extract just its file name
        return audioRecordings.map { $0.fileName }
    }
    
    /// Initializes the ViewModel and its dependent services.
    /// - Parameters:
    ///   - isPreview: Set to `true` for SwiftUI Previews to load mock data.
    ///   - fileService: The service for file operations.
    ///   - audioSessionService: The service for session management.
    ///   - recordingService: The service for recording operations.
    init(
        isPreview: Bool = false,
        fileService: AudioFileService? = nil,
        audioSessionService: AudioSessionService = AudioSessionService(),
        recordingService: RecordingService = RecordingService()
    ) {
        self.isPreview = isPreview
        self.audioSessionService = audioSessionService
        self.recordingService = recordingService
        
        // Use provided service or create a new one
        if let providedService = fileService {
            self.fileService = providedService
        } else {
            self.fileService = AudioFileService(isPreview: isPreview)
        }
        
        if isPreview {
            print("DEBUG: Setting up preview data")
            self.hasPermission = true
            // Use the mock initializer or static mock data
            self.audioRecordings = AudioRecording.mockRecordings()
        } else {
            print("DEBUG: ViewModel initialized for real device")
            self.hasPermission = false
            self.audioRecordings = []
        }
        
        setupBindings()
    }
    
    /// Sets up the Combine pipelines that automatically sync state between the services and the ViewModel.
    ///
    /// This private method is called once during initialization. It is the central "switchboard" for all
    /// reactive communication in the app. It creates several subscriptions to ensure the ViewModel's
    /// properties stay in sync with the state of the underlying services.
    ///
    /// The function sets up two kinds of rules:
    /// 1.  Mirroring Rules: It uses `assign(to:on:)` to create simple, one-way data flows from a service's
    ///     `@Published` property to the ViewModel's corresponding `@Published` property. This is used for
    ///     properties like `hasPermission`, `availableChannels`, and `isRecording`.
    /// 2.  Action Rules: It uses `sink` to perform custom logic in response to a state change. This is used
    ///     for more complex reactions, like telling the `AudioFileService` to refresh its list when a recording
    ///     has finished, or updating the `enabledChannels` array when the number of available channels changes.
    ///
    /// All subscriptions are stored in the `cancellables` set to keep them alive for the lifetime of the ViewModel.
    private func setupBindings() {
        // Mirror properties from the File Service
        fileService.$audioRecordings
            .assign(to: \.audioRecordings, on: self)
            .store(in: &cancellables)
            
        // Mirror properties from the Audio Session Service
        audioSessionService.$hasPermission
            .assign(to: \.hasPermission, on: self)
            .store(in: &cancellables)
        audioSessionService.$showingPermissionAlert
            .assign(to: \.showingPermissionAlert, on: self)
            .store(in: &cancellables)
        audioSessionService.$availableChannels
            .assign(to: \.availableChannels, on: self)
            .store(in: &cancellables)
        audioSessionService.$maxChannels
            .assign(to: \.maxChannels, on: self)
            .store(in: &cancellables)
        audioSessionService.$currentInputSource
            .assign(to: \.currentInputSource, on: self)
            .store(in: &cancellables)
        audioSessionService.$channelNames
            .assign(to: \.channelNames, on: self)
            .store(in: &cancellables)
        audioSessionService.$availableInputNames
            .assign(to: \.availableInputNames, on: self)
            .store(in: &cancellables)
            
        // Mirror the recording state from the Recording Service
        recordingService.$isRecording
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)

        // When recording STOPS, refresh the file list
        recordingService.$isRecording
            .dropFirst()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.fileService.refreshAudioFiles()
            }
            .store(in: &cancellables)

        // When the channel count CHANGES, update the enabled toggles
        audioSessionService.$availableChannels
            .sink { [weak self] channelCount in
                
                guard let self = self else { return }
                
                if !self.isPreview {
                    if self.enabledChannels.count != channelCount {
                        self.enabledChannels = Array(repeating: true, count: channelCount)
                        self.channelGainLevels = Array(repeating: 1.0, count: channelCount)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Kicks off the main asynchronous setup tasks for the ViewModel.
    func initialize() {
        // Skip initialization for previews
        if isPreview { return }
        
        // Give the starting commands to the two services
        fileService.refreshAudioFiles()
        audioSessionService.requestPermission()
    }
    
    /// Scans the app's Documents directory for saved audio files and updates the `audioRecordings` array.
    func refreshAudioFiles() {
        fileService.refreshAudioFiles()
    }
    
    /// Tells the `AudioFileService` to delete recordings at the specified offsets.
    /// - Parameter offsets: An `IndexSet` from the SwiftUI view's `.onDelete` modifier.
    func delete(at offsets: IndexSet) {
        fileService.delete(at: offsets, from: self.audioRecordings)
    }
    
    
    /// Tells the `RecordingService` to start a new recording.
    func startRecording() {
        recordingService.startRecording(isMultichannel: self.isMultichannelMode, enabledChannels: self.enabledChannels, channelGainLevels: self.channelGainLevels)
    }
    
    /// Tells the `RecordingService` to stop the current recording.
    func stopRecording() {
        recordingService.stopRecording()
    }
    
    /// Checks whether the audio channel at a specific index is currently enabled.
    ///
    /// This is a helper function to easily access the state from the `enabledChannels` array.
    ///
    /// - Parameter index: The zero-based index of the channel to check.
    /// - Returns: `true` if the channel at the given index is enabled; otherwise, `false`.
    func isMicEnabled(_ index: Int) -> Bool {
        guard enabledChannels.indices.contains(index) else {
            return true
        }
    
        return enabledChannels[index]
    }
    
    /// Toggles the enabled state of the audio channel at a specific index.
    ///
    /// This function flips the boolean value at the given position in the `enabledChannels` array.
    ///
    /// - Parameter index: The zero-based index of the channel to toggle.
    func toggleMic(_ index: Int) {
        guard enabledChannels.indices.contains(index) else {
            return
        }
        
        enabledChannels[index].toggle()
    }
    

    /// Represents the specific errors that can occur during the audio recording setup process.
    ///
    /// Conforming to the `Error` protocol allows this enum to be used in Swift's `do-try-catch` error handling system.
    /// Each case represents a distinct failure point in the audio pipeline.
    enum AudioRecordingError: Error {
        case formatCreationFailed
        case audioSessionSetupFailed
        case engineStartFailed
        
        var localizedDescription: String {
            switch self {
            case .formatCreationFailed:
                return "Failed to create audio format"
            case .audioSessionSetupFailed:
                return "Failed to setup audio session"
            case .engineStartFailed:
                return "Failed to start audio engine"
            }
        }
    }
}

/// An extension to `AudioRecordingViewModel` that provides convenience methods for SwiftUI Previews.
extension AudioRecordingViewModel {
    
    /// A static factory method that creates and returns a pre-configured ViewModel for use in SwiftUI Previews.
    ///
    /// This function initializes the ViewModel in its "preview" state, which populates it with mock data
    /// and prevents it from trying to access live hardware like the microphone. This is essential for rendering
    /// views in the Xcode preview canvas.
    ///
    /// - Returns: A new instance of `AudioRecordingViewModel` configured for previewing.
    static func mockViewModel() -> AudioRecordingViewModel {
        let mv = AudioRecordingViewModel(isPreview: true)
        
        mv.hasPermission = true
        mv.audioRecordings = AudioRecording.mockRecordings()
        mv.availableChannels = 2
        mv.channelNames = ["Mic 1", "Mic 2"]
        mv.enabledChannels = [true, true]
        mv.channelGainLevels = [1.0, 1.0]
        
        return mv
    }
}
