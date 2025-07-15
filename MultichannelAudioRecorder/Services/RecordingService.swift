//
//  RecordingService.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 7/8/25.
//

import Foundation
import AVFoundation

class RecordingService: NSObject, ObservableObject {

    /// The `AVAudioEngine` used for complex audio processing, specifically for multichannel recording in this case.
    private var audioEngine: AVAudioEngine!
    
    /// The legacy `AVAudioRecorder` used for simpler, single-channel recording.
    private var audioRecorder: AVAudioRecorder?
    
    /// The file on disk that the audio engine writes to during a multichannel recording.
    /// This is nil when no multichannel recording is in progress.
    private var audioFile: AVAudioFile?
    
    /// The current recording state of the app. This drive the UI of the record button and the timer.
    @Published var isRecording: Bool = false
    
    /// Stores the state of the channel toggles for the current recording session.
    ///
    /// This array is set by the public `startRecording` method and is used by `muteDisabledChannels`
    /// to determine which audio channels to write to the file.
    private var enabledChannels: [Bool] = []
    
    /// Stores the gain levels for each audio channel.
    ///
    /// This array is populated by the `startRecording` method and is used by `applyGainLevels`
    /// to get the correct gain factor to apply to each channel's audio buffer.
    private var channelGainLevels: [Float] = []
    
    /// Starts the recording process.
    ///
    /// If the program is in multichannel recording mode, then it calls on `startMultichannelRecording()`.
    /// If the program is in single channel recording mode, then it calls on `startSingleChannelRecording()`.
    func startRecording(isMultichannel: Bool, enabledChannels: [Bool], channelGainLevels: [Float]) {
        
        self.enabledChannels = enabledChannels
        self.channelGainLevels = channelGainLevels
        
        if isMultichannel {
            print("multichannelmode on")
            startMultichannelRecording()
        } else {
            print("multichannelmode off")
            startSingleChannelRecording()
        }
    }
    
    /// Initiates a new recording using the legacy `AVAudioRecorder` for single-channel audio.
    ///
    /// This function handles the entire process for a standard, single-channel recording. It follows these steps:
    /// 1. Gets a reference to the shared `AVAudioSession` and activates it.
    /// 2. Generates a unique, timestamped filename and determines the file path in the app's Documents directory.
    /// 3. Defines the audio settings for the recording (format, sample rate, channels, quality).
    /// 4. Initializes a new `AVAudioRecorder` instance with the specified URL and settings.
    /// 5. Begins the recording and updates the `isRecording` state on the main thread to refresh the UI.
    ///
    /// If any step in the setup fails, the process is aborted and a cleanup is performed.
    private func startSingleChannelRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true)
        
        Thread.sleep(forTimeInterval: 0.1)

        let audioFilename = getNewRecordingURL(isMultichannel: false)
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        
        audioRecorder = try? AVAudioRecorder(url: audioFilename, settings: settings)
        
        guard audioRecorder?.prepareToRecord() == true else {
            print("Failed to prepare audio recorder")
            return
        }
        
        audioRecorder?.record()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }

    }

    
    /// Initiates new multichannel audio recording using the `AVAudioEngine`.
    ///
    /// This function handles the entire process for a multichannell recording. It follows these steps:
    /// 1. Performs a safety check to ensure a recording is not already in progress.
    /// 2. Calls `setupAudioEngine()` to configure and start the audio engine and its processing tap.
    /// 3. Generates a unique, timestamped filename with a `.caf` extension for the newrecording.
    /// 4. Creates a new, empty audio file on the disk at the specified path, ready to receive audio data.
    /// 5.  Updates the `isRecording` state on the main thread to refresh the UI.
    ///
    /// If any step in this `do-try-catch` block fails, the recording is stopped and the error is printed.
    private func startMultichannelRecording() {
        audioEngine = AVAudioEngine()
        
        do {
            let inputNode = audioEngine.inputNode
            let liveFormat = inputNode.outputFormat(forBus: 0)
            
            try setupAudioEngine(using: inputNode, with: liveFormat)

            let fileSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: liveFormat.sampleRate,
                AVNumberOfChannelsKey: liveFormat.channelCount,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: true // <-- This is the key for DAW compatibility
            ]
            
            let audioFilename = getNewRecordingURL(isMultichannel: true)
            
            // Create the audio file with your explicit settings
            audioFile = try AVAudioFile(forWriting: audioFilename, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)

            self.isRecording = true
            
        } catch {
            print("Could not start multichannel recording: \(error.localizedDescription)")
            stopMultiChannelRecording()
        }
    }
    
    /// Stops the active recording process and updates the app's state.
    ///
    /// This function acts as a central handler for stopping any recording. It performs these key steps in order:
    /// 1.  Calls the appropriate stop method (`stopMultiChannelRecording` or `stopSingleChannelRecording`)
    ///     based on the current `isMultichannelMode`.
    /// 2.  Dispatches a UI update to the main thread to set `isRecording` to `false`.
    func stopRecording() {
        // Check which engine is active and stop it.
        if audioEngine != nil && audioEngine.isRunning {
            stopMultiChannelRecording()
        } else if audioRecorder?.isRecording == true { // <-- This is the corrected line
            stopSingleChannelRecording()
        }
    }
    
    /// Stops the single channel recording currently in progress by the `AVAudioRecorder`.
    ///
    /// This function calls the `stop()` method on the `audioRecorder` instance. This action finalizes the
    /// audio file on disk, making it playable. The use of optional chaining (`?`) ensures that this
    /// method does nothing and does not crash if no recording is currently in progress (i.e., if `audioRecorder` is `nil`).
    func stopSingleChannelRecording() {
        audioRecorder?.stop()
        self.isRecording = false
        audioRecorder = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Stops the multichannel recording session currently in progress.
    ///
    /// This process is done in the following steps:
    /// 1. Removes the tap from the input node, which stops the `processAudioBuffer` function from being called.
    /// 2. Stops the audio engine itself, stopping all audio processing.
    /// 3. Sets the `audioFile` property to `nil`, closing the reference to the file on disk and making it ready for playback.
    private func stopMultiChannelRecording() {
        if audioEngine != nil && audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        self.isRecording = false
        audioFile = nil
        audioEngine = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Configures and prepares the `AVAudioEngine` for multichannel recording.
    ///
    /// This function establishes the audio processing chain by installing a "tap" on the input node
    /// to intercept audio buffers. It then prepares and starts the engine.
    /// - Throws: An error if the engine fails to prepare or start.
    private func setupAudioEngine(using inputNode: AVAudioInputNode, with format: AVAudioFormat) throws {

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    /// Processes a single buffer of audio data from the engine's tap.
    ///
    /// This function first mutes any disabled channels, applies adjusted gain levels, and then writes the resulting buffer
    /// to the audio file on disk.
    /// - Parameter buffer: The `AVAudioPCMBuffer` containing the latest chunk of raw audio samples.
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        muteDisabledChannels(buffer) // Mute channels before writing
        applyGainLevels(buffer)
        
        do {
            try audioFile?.write(from: buffer)
        } catch {
            print("Error writing audio buffer: \(error)")
        }
    }
    
    /// Mutes disabled audio channels by writing silence into the audio buffer.
    ///
    /// This function iterates through the `enabledChannels` array and, for any channel marked as `false`,
    /// it overwrites that channel's audio samples in the provided buffer with zeros.
    ///
    /// - Parameter buffer: The `AVAudioPCMBuffer` whose audio data will be directly modified.
    private func muteDisabledChannels(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let bufferChannels = Int(buffer.format.channelCount)
        guard enabledChannels.count == bufferChannels else { return }
        
        for i in 0..<bufferChannels {
            if !enabledChannels[i] {
                // Set the buffer for this channel to all zeros
                let channelPointer = channelData[i]
                for j in 0..<Int(buffer.frameLength) {
                    channelPointer[j] = 0.0
                }
            }
        }
    }
    
    /// Applies the adjusted gain levels to each channel.
    ///
    /// This function iterates the `channelGainLevels` array and, for any channel that does not have
    /// the default value of 1.0, it overwrites that channel's audio samples in the provided buffer with its
    /// value multiplied by the appropriate new gain level.
    ///
    /// - Parameter buffer: The `AVAudioPCMBuffer` whose audio data will be directly modified.
    private func applyGainLevels(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let bufferChannels = Int(buffer.format.channelCount)
        guard channelGainLevels.count == bufferChannels else { return }
        
        for i in 0..<bufferChannels {
            if channelGainLevels[i] != 1.0 {
                // Apply new gain level
                let channelPointer = channelData[i]
                let gain = channelGainLevels[i]
                
                for j in 0..<Int(buffer.frameLength) {
                    channelPointer[j] = channelPointer[j] * gain
                }
            }
        }
    }
    
    /// Creates a unique, timestamped URL for a new recording file.
    /// - Parameter isMultichannel: A boolean that determines the file extension (`.caf` or `.m4a`).
    /// - Returns: A complete URL pointing to a new file in the app's documents directory.
    private func getNewRecordingURL(isMultichannel: Bool) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileExtension = isMultichannel ? "caf" : "m4a"
        let filename = "Recording_\(timestamp).\(fileExtension)"
        return documentsPath.appendingPathComponent(filename)
    }
}

