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

class AudioRecordingViewModel: ObservableObject {
    
    // MARK: - Services
    private let fileService: AudioFileService
    
    // MARK: - @Published UI State
    
    /// The list of all audio recordings. This property is the main data source for the UI's list view.
    @Published var audioRecordings: [AudioRecording] = []
    
    /// A Boolean indicating if the app has been granted microphone permission.
    @Published var hasPermission = false
    
    /// Controls the presentation of the alert show to the user when microphone permission has been denied.
    @Published var showingPermissionAlert = false {
        // This `didSet` block is useful for debugging to see when this value changes.
        didSet {
            print("DEBUG: showingPermissionAlert changed to \(showingPermissionAlert)")
        }
    }
    
    /// The current recording state of the app. This drive the UI of the record button and the timer.
    @Published var isRecording: Bool = false
    
    // MARK: - @Published Audio Hardware State
    
    /// A Boolean indicating if mulichannel recording mode is on, controlled by the toggle in Settings.
    @Published var isMultichannelMode: Bool = false
    
    /// The number of input channels that are currently active and configured in the audio session.
    ///
    /// This number can change based on the app's configuration and may be less than `maxChannels`.
    @Published var availableChannels: Int = 0
    
    /// The maxmimum number of channels the connected audio hardware can theoretically support
    ///
    /// This value represents the hardware's capability (e.g., a Scarlett 2i2 has a `maxChannels` of 2).
    /// It is used to determine if multichannel mode is possible and how many channels to request.
    @Published var maxChannels: Int = 0
    
    /// The display name of the current audio input source.
    @Published var currentInputSource: String = "Unknown"
    
    /// Array of each available channels (e.g. "Scarlett 2i2 Channel 1", "Scarlett 2i2 Channel 2")
    @Published var channelNames: [String] = []

    /// An array of names for all discoverable audio inputs available to the system (e.g. "iPhone Microphone", "Scarlett 2i2")
    @Published var availableInputNames: [String] = []
    
    /// An array of Booleans that could be used to enable or disable specific channels for recording.
    @Published var enabledChannels: [Bool] = []
    
    /// The name of the currently selected input device.
    @Published var inputDeviceName: String = "Unknown Input"
    
    /// The `AVAudioEngine` used for complex audio processing, specifically for multichannel recording in this case.
    private var audioEngine: AVAudioEngine!
    
    /// The file on disk that the audio engine writes to during a multichannel recording.
    private var audioFile: AVAudioFile?
    
    /// The legacy `AVAudioRecorder` used for simpler, single-channel recording.
    private var audioRecorder: AVAudioRecorder?
    
    /// The app's shared `AVAudioSEssion`, used to configure the app's audio behavior with the iOS system.
    private var recordingSession: AVAudioSession?
    
    ///
    private var debugBufferCount = 0
    
    // MARK: - Combine
    
    /// Set to store Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Internal State
    
    /// A Boolean that is true when the ViewModel is instantiated for SwiftUI's Previews, used to load mock data.
    private let isPreview: Bool
    
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
    
    /// Initializes a new instance of the ViewModel.
    ///
    /// This initializer performs the minimal, synchronous setup required to create the object. Its primary role is to
    /// differentiate between a "live" app environment and an Xcode Preview, loading mock data for previews.
    /// Any slow or asynchronous work is deferred to the `initialize()` method to keep the app launch responsive.
    ///
    /// - Parameter isPreview: A Boolean that should be `true` only when the ViewModel is being used
    ///   in an Xcode Preview. Defaults to `false`.
    /// - Parameter fileService: Optional file service for dependency injection (mainly for testing)
    init(isPreview: Bool = false, fileService: AudioFileService? = nil) {
        self.isPreview = isPreview
        
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
    
    /// Sets up Combine bindings between the file service and the ViewModel
    private func setupBindings() {
        // Bind file service's audioRecordings to our published property
        fileService.$audioRecordings
            .assign(to: \.audioRecordings, on: self)
            .store(in: &cancellables)
        
        // When recording stops, refresh the file list
        $isRecording
            .filter { !$0 } // Only when recording stops (becomes false)
            .sink { [weak self] _ in
                self?.refreshAudioFiles()
            }
            .store(in: &cancellables)
    }
    
    /// Kicks off the main asynchronous setup tasks for the ViewModel.
    ///
    /// This method should be called when the main UI appears (e.g., in `.onAppear`). It handles tasks that
    /// are too slow or require UI interaction to be run in the `init()` method. This includes refreshing the list
    /// of audio files from disk and requesting microphone permissions from the user.
    func initialize() {
        // Skip initialization for previews since they use mock data
        if isPreview {
            return
        }
        
        // Check if running in Xcode previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("DEBUG: Running in Xcode previews, setting mock permission")
            DispatchQueue.main.async {
                self.hasPermission = true
            }
        } else {
            // Do file refresh in background immediately
            DispatchQueue.global(qos: .userInitiated).async {
                self.refreshAudioFiles()
            }
            
            // Request permission
            requestPermission()
        }
    }
    
    /// Checks the current microphone permission status and requests it from the user if ncessary.
    ///
    /// This function handles the three possible permission states:
    /// - **`.granted` **: If permission is already granted, it configures the audio session for recording.
    /// - **`.denied`**: If permission has been previously denied, it prepares an alert to inform the user.
    /// - **`.undetermined`**: If permission has not been asked for yet, it presents the system's permission request prompt
    /// to the user and handles their response.
    ///
    /// This is a critical part of the app's startup sequence, as the ability to record audio depends on a successful outcome.
    func requestPermission() {
        // Skip for previews
        guard !isPreview else { return }
        
        let currentStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch currentStatus {
        case .granted:
            print("DEBUG: Permission already granted")
            DispatchQueue.main.async {
                self.hasPermission = true
            }
            // Configure audio session on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                self.configureAudioSession()
            }
            
        case .denied:
            print("DEBUG: Permission previously denied")
            DispatchQueue.main.async {
                self.hasPermission = false
                self.showingPermissionAlert = true
            }
            
        case .undetermined:
            print("DEBUG: Permission undetermined, requesting...")
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                print("DEBUG: Permission response: \(allowed)")
                DispatchQueue.main.async {
                    if allowed {
                        self.hasPermission = true
                        // Configure audio session on background thread
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.configureAudioSession()
                        }
                    } else {
                        self.hasPermission = false
                        self.showingPermissionAlert = true
                    }
                }
            }
            
        @unknown default:
            print("DEBUG: Unknown permission status")
            DispatchQueue.main.async {
                self.hasPermission = false
            }
        }
    }

    /// Configures the app's shared `AVAudioSession` for recording.
    ///
    /// This is a critical setup function that must be called before any recording can begin. It performs a sequence of hardware
    /// configuration steps on a background thread to avoid blocking the UI.
    ///
    /// The configuration sequence is as follows:
    /// 1. Sets the session's category to `.playAndRecord` and activates the session.
    /// 2. Scans for all available physical inputs and calls `selectBestAudioInput()` to choose the most appropriate one
    /// (e.g. `.usbAudio` over `.builtInMic`)
    /// 3. Sets the selected device as the preferred input for the system.
    /// 4. Determines the number of channels to activate based on whether `isMultichannelMode` is enabled.
    /// 5. Logs and verifies the final hardware configuration for debugging purposes.
    /// 6. Dispatches a final UI update to the main thread to reflect the new hardware state.
    func configureAudioSession() {
        print("DEBUG: Starting audio session configuration...")
        // Perform audio work on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()

                // Set Category and Activate Session First
               
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
    
                try session.setActive(true)
                
                // Find and Set the Preferred Input
                guard let availableInputs = session.availableInputs,
                        let preferredInput = self.selectBestAudioInput(from: availableInputs) else {
                    print("ERROR: No suitable input device found.")
                    // Fallback to default or handle error
                    self.updateUIWithCurrentState(session: session)
                    return
                }

                print("DEBUG: Found preferred input: \(preferredInput.portName) (Type: \(preferredInput.portType.rawValue))")
                try session.setPreferredInput(preferredInput)

                // Configure the number of channels on the *active* input
                var desiredChannels = 1
                if self.isMultichannelMode {
                    let maxInputChannels = session.maximumInputNumberOfChannels
                    print("DEBUG: Interface Max Channels: \(maxInputChannels)")
                    if maxInputChannels > 1 {
                        desiredChannels = maxInputChannels
                        print("DEBUG: Multichannel mode - requesting all \(desiredChannels) available channels.")
                    } else {
                        print("WARNING: Multichannel mode requested, but the selected interface only supports 1 channel.")
                    }
                } else {
                    print("DEBUG: Single-channel mode - requesting 1 channel.")
                }
                
                try session.setPreferredInputNumberOfChannels(desiredChannels)
                

                // Final Verification
                print("DEBUG: Final configuration complete.")
                self.logAudioInterfaceCapabilities()
                self.verifyMultichannelSetup(session: session)
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.updateUIWithCurrentState(session: session)
                }

            } catch {
                print("ERROR: Failed to configure audio session: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.hasPermission = false
                }
            }
        }
    }
    
    /// Logs a detailed summary of the current audio hardware's capabilities to the console.
    ///
    /// This is a private helper function used for debugging. It prints key information after the audio session has been
    /// configured, which is useful for verifying that the hardware is set up as expected.
    private func logAudioInterfaceCapabilities() {
        let session = AVAudioSession.sharedInstance()
        
        // Makes sure that an audio inputs exists. Else, notify that there is no available input.
        guard let currentInput = session.currentRoute.inputs.first else {
            print("=== NO CURRENT INPUT AVAILABLE ===")
            return
        }
        
        print("=== CURRENT INTERFACE CAPABILITIES ===")
        print("Name: \(currentInput.portName)")
        
        print("Session reports:")
        print("  - Input channels: \(session.inputNumberOfChannels)")
        print("  - Max input channels: \(session.maximumInputNumberOfChannels)")
        print("  - Preferred channels: \(session.preferredInputNumberOfChannels)")
        print("=====================================")
    }

    /// Selects the best audio input from a list of available hardware based on a predefined order of preference.
    ///
    /// The preference order (`.usbAudio`, `.headsetMic`, `.builtInMic`) is designed to prioritize external,
    /// higher-quality interfaces first. This is crucial for multichannel mode to ensure that if a capable
    /// device is connected, it is selected automatically.
    ///
    /// - Parameter inputs: An array of `AVAudioSessionPortDescription` objects that represent the currently available hardware inputs
    /// - Returns The first `AVAudioSessionPortDescription` that matches the preferred criteria, or `nil` if no suitable input is found.
    private func selectBestAudioInput(from inputs: [AVAudioSessionPortDescription]) -> AVAudioSessionPortDescription? {
        
        let preferredPortTypes: [AVAudioSession.Port] = [.usbAudio, .headsetMic, .builtInMic]
        
        print("DEBUG: Found \(inputs.count) available inputs:")
        for input in inputs {
            print("  - \(input.portName) (Type: \(input.portType.rawValue))")
        }
        
        for portType in preferredPortTypes {
            if let foundInput = inputs.first(where: { $0.portType == portType }) {
                return foundInput
            }
        }
        
        // Fallback to the first available input
        return inputs.first
    }
        
    /// Updates the ViewModel's properties with the latest information from the audio hardware.
    ///
    /// This is a helper function that takes the current audio session and uses it to set the values
    /// for all the UI-related properties like `availableChannels`, `channelNames`, and `currentInputSource`.
    ///
    /// It centralizes the logic for refreshing the audio state in one place. It also creates generic
    /// channel names (e.g., "Channel 1") if the connected hardware does not provide specific names.
    ///
    /// - Parameter session: The currently active `AVAudioSession` to read information from.
    private func updateUIWithCurrentState(session: AVAudioSession) {
        self.hasPermission = true
        self.availableChannels = session.inputNumberOfChannels
        self.maxChannels = session.maximumInputNumberOfChannels
        self.currentInputSource = session.currentRoute.inputs.first?.portName ?? "Unknown"
        self.inputDeviceName = session.currentRoute.inputs.first?.portName ?? "Unknown Input"
        print("DEBUG: UI updated - showing \(self.availableChannels) available channels.")
        
        if let availableInputs = session.availableInputs {
            // Map the array of PortDescriptions to an array of just their names
            self.availableInputNames = availableInputs.map { $0.portName }
        } else {
            self.availableInputNames = ["No inputs found"]
        }
        
        if let currentInput = session.currentRoute.inputs.first, currentInput.channels != nil {
            // Map the array of ChannelDescriptions to an array of just their names
            self.channelNames = currentInput.channels!.map { $0.channelName }
        } else {
            // Fallback for devices that have channels but don't report names (or for single channel mode)
            if session.inputNumberOfChannels > 0 {
                // Create generic names like "Channel 1", "Channel 2"
                self.channelNames = (1...session.inputNumberOfChannels).map { "Channel \($0)" }
            } else {
                self.channelNames = []
            }
        }
        
        
        if self.enabledChannels.count != session.inputNumberOfChannels {
            self.enabledChannels = Array(repeating: true, count: session.inputNumberOfChannels)
            print("DEBUG: Initialized enabledChannels: \(self.enabledChannels)")
        }
        print("DEBUG: Configured enabledChannels: \(self.enabledChannels)")
    }
        
    /// Verifies and logs whether the audio session was successfully configured for the intended recording mode.
    ///
    /// This is a private helper function used for debugging. It checks the final number of active channels against the
    /// `isMultichannelMode` flag and prints a "SUCCESS", "WARNING", or "INFO" message to the console.
    ///
    /// - Parameter session: The active `AVAudioSession` whose final state will be verified.
    private func verifyMultichannelSetup(session: AVAudioSession) {
        let finalChannelCount = session.inputNumberOfChannels
        if isMultichannelMode && finalChannelCount > 1 {
            print("SUCCESS: Multichannel setup active with \(finalChannelCount) channels")
        } else if isMultichannelMode && finalChannelCount <= 1 {
            print("WARNING: Multichannel mode requested but only \(finalChannelCount) channel(s) are active.")
        } else {
            print("INFO: Single-channel mode active with \(finalChannelCount) channel(s).")
        }
    }
    
    /// Scans the app's Documents directory for saved audio files and updates the `audioRecordings` array.
    func refreshAudioFiles() {
        fileService.refreshAudioFiles()
    }
    
    /// Deletes audio recordings from both the user interface and the device's file system.
   ///
   /// - Parameter offsets: An `IndexSet` provided by SwiftUI's `.onDelete` modifier
   func delete(at offsets: IndexSet) {
       fileService.delete(at: offsets)
   }
    
    /// Configures and prepares the `AVAudioEngine` for multichannel recording.
    ///
    /// This function is the core of the multichannel recording setup. It establishes the audio processing chain,
    /// from the microphone input to the point where the audio data can be written to a file. This function must
    /// be called before `startMultichannelRecording()` can succeed.
    ///
    /// The setup process involves 3 steps:
    /// 1. Getting a reference to the engine's `inputNode`, which represents the microphone.
    /// 2. Installing a "tap" on the input node. This tap allows us to inercept and copy the raw audio data
    ///   as it flows through the microphone.
    /// 3. Finally, preparing and starting the audio engine which makes it ready to process audio.
    ///
    /// - Throws: This function can throw an error if the `audioEngine` fails to prepare or start, which could happen
    ///   if the audio hardware is in a bad state or is not available.
    private func setupAudioEngine() throws {
        // The part of the audio engine that receives microphone input
        let inputNode = audioEngine.inputNode
        
        // The format of audio coming from the microphone
        let inputFormat = inputNode.outputFormat(forBus: 0)
//        self.configureChannels(from: inputFormat)
        
        print("Input format: \(inputFormat)")
        print("Channel count: \(inputFormat.channelCount)")
        
        let recordingFormat = inputFormat
        
        // Create a "tap" that copies audio data as it flows through
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: recordingFormat
        ) { [weak self] buffer, time in
                self?.muteDisabledChannels(buffer)
                self?.processAudioBuffer(buffer, at: time)
            }
        
        // prepare and start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    /// Processes a single buffer of audio data by writing its contents to the active recording file.
    ///
    /// This function is called repeatedly by the audio engine's "tap" during a multichannel recording. Each time a new
    /// chunk (buffer) of audio data is captured from the microphone, this function is executed to handle that chunk.
    ///
    /// It safely unwraps the optional `audioFile` property to ensure that it only attempts to write data
    /// if a recording is actively in progress.
    ///
    /// - Parameters:
    ///     - buffer: An `AVAudioPCMBuffer` containing the latest chunck of raw audio samples from the input.
    ///     - time: The timestamp indicating when the buffer was captured. This is provided by the audio engine.
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        
        #if DEBUG
        // Debug every 50th buffer (about once per second)
        debugBufferCount += 1
        
        if debugBufferCount % 50 == 0 {
            debugChannelActivity(buffer)
        }
        #endif
        
        // Write to file if recording
        if let audioFile = audioFile {
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Error writing audio buffer: \(error)")
            }
        }
    }
    
    #if DEBUG
    private func debugChannelActivity(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        
        print("=== AUDIO DEBUG ===")
        print("Format: \(buffer.format)")
        print("Channels in buffer: \(channelCount)")
        print("Frame length: \(buffer.frameLength)")
        
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            var maxAmplitude: Float = 0
            var activeFrames = 0
            
            // Check activity in this channel
            for frame in 0..<Int(buffer.frameLength) {
                let sample = abs(samples[frame])
                maxAmplitude = max(maxAmplitude, sample)
                if sample > 0.001 { // Threshold for "active" audio
                    activeFrames += 1
                }
            }
            
            let activityPercent = (Float(activeFrames) / Float(buffer.frameLength)) * 100
            print("Channel \(channel): Max=\(String(format: "%.4f", maxAmplitude)), Active=\(String(format: "%.1f", activityPercent))%")
        }
        print("==================")
    }
    #endif
    
    /// Starts the recording process.
    ///
    /// If the program is in multichannel recording mode, then it calls on `startMultichannelRecording()`.
    /// If the program is in single channel recording mode, then it calls on `startSingleChannelRecording()`.
    func startRecording() {
        if isMultichannelMode {
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
    func startSingleChannelRecording() {
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
                stopSingleChannelRecording() // Clean up
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
        guard !isRecording else { return }
        
        audioEngine = AVAudioEngine()
        
        do {
            
            try setupAudioEngine()
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let audioFilename = documentsPath.appendingPathComponent("Multichannel_Recording_\(dateFormatter.string(from: Date())).caf")
            
            let inputNode = audioEngine.inputNode
            let liveFormat = inputNode.outputFormat(forBus: 0)

            // Explicitly define the file format settings for maximum compatibility.
            let fileSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: liveFormat.sampleRate,
                AVNumberOfChannelsKey: liveFormat.channelCount,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: true
            ]

            // Create the audio file with our explicit, compatible settings.
            audioFile = try AVAudioFile(forWriting: audioFilename, settings: fileSettings)
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
            
            print("DEBUG: Started multichannel recording to \(audioFilename)")
//            print("DEBUG: Recording with \(recordingFormat.channelCount) channels")
            
        } catch {
            print("Could not start multichannel recording: \(error.localizedDescription)")
            stopRecording()
        }
    }
    
    /// Stops the active recording process and updates the app's state.
    ///
    /// This function acts as a central handler for stopping any recording. It performs these key steps in order:
    /// 1.  Calls the appropriate stop method (`stopMultiChannelRecording` or `stopSingleChannelRecording`)
    ///     based on the current `isMultichannelMode`.
    /// 2.  Dispatches a UI update to the main thread to set `isRecording` to `false`.
    /// 3.  Calls `refreshAudioFiles()` to scan the disk for the newly created recording so it appears in the list.
    func stopRecording() {
        if isMultichannelMode {
            stopMultiChannelRecording()
        } else {
            stopSingleChannelRecording()
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        refreshAudioFiles()
        
        print("DEBUG: Stopped recording.")
    }
    
    /// Stops the single channel recording currently in progress by the `AVAudioRecorder`.
    ///
    /// This function calls the `stop()` method on the `audioRecorder` instance. This action finalizes the
    /// audio file on disk, making it playable. The use of optional chaining (`?`) ensures that this
    /// method does nothing and does not crash if no recording is currently in progress (i.e., if `audioRecorder` is `nil`).
    func stopSingleChannelRecording() {
        audioRecorder?.stop()
    }
    
    /// Stops the multichannel recording session currently in progress.
    ///
    /// This process is done in the following steps:
    /// 1. Removes the tap from the input node, which stops the `processAudioBuffer` function from being called.
    /// 2. Stops the audio engine itself, stopping all audio processing.
    /// 3. Sets the `audioFile` property to `nil`, closing the reference to the file on disk and making it ready for playback.
//    func stopMultiChannelRecording() {
//        audioEngine.inputNode.removeTap(onBus: 0)
//        audioEngine.stop()
//        audioFile = nil
//    }
    func stopMultiChannelRecording() {
        // 1. Check if the engine exists and is running to prevent crashes.
        if audioEngine != nil && audioEngine.isRunning {
            // 2. Remove the tap and stop the engine.
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        // 3. Finalize the audio file.
        audioFile = nil
        
        // 4. Release the engine instance to be created fresh next time.
        audioEngine = nil
    }
    
    /// Checks whether the audio channel at a specific index is currently enabled.
    ///
    /// This is a helper function to easily access the state from the `enabledChannels` array.
    ///
    /// - Parameter index: The zero-based index of the channel to check.
    /// - Returns: `true` if the channel at the given index is enabled; otherwise, `false`.
    func isMicEnabled(_ index: Int) -> Bool {
            return enabledChannels[index]
    }
    
    /// Toggles the enabled state of the audio channel at a specific index.
    ///
    /// This function flips the boolean value at the given position in the `enabledChannels` array.
    ///
    /// - Parameter index: The zero-based index of the channel to toggle.
    func toggleMic(_ index: Int) {
            enabledChannels[index].toggle()
    }
    
    /// Mutes disabled audio channels by directly writing zeros into the audio buffer's memory.
    ///
    /// This is a low-level audio processing function designed to be called from the audio engine's tap before the
    /// buffer is written to a file. It iterates through the channels and, for any channel marked as disabled in the
    /// `enabledChannels` array, it overwrites all of that channel's audio samples in the current buffer with silence (zeros).
    ///
    /// The process involves these key safety and logic steps:
    /// 1. Safely unwraps the buffer's `floatChannelData`, which provides direct memory access to the audio samples.
    /// 2. Performs a safety check to ensure the `enabledChannels` array and the buffer's channel count match.
    /// 3. Loops through each channel safely, using `min()` to prevent out-of-bounds crashes.
    /// 4. For disabled channels, iterate through every sample in the buffer and set its value to zero.
    ///
    /// - Parameter buffer: The `AVAudioPCMBuffer` whose audio data will be directly modified.
    private func muteDisabledChannels(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let bufferChannels = Int(buffer.format.channelCount)
            
        // Log warning if sizes don't match
        if enabledChannels.count != bufferChannels {
            print("Warning: enabledChannels size (\(enabledChannels.count)) doesn't match buffer channels (\(bufferChannels))")
        }
        
        // Go through each channel and mute if disabled
        for i in 0..<min(bufferChannels, enabledChannels.count) {
            if !enabledChannels[i] {
                let channelPointer = channelData[i]
                
                for j in 0..<Int(buffer.frameLength) {
                    channelPointer[j] = 0.0
                }
            }
        }
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
        return AudioRecordingViewModel(isPreview: true)
    }
}
