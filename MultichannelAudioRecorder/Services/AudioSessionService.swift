//
//  AudioSessionService.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 7/8/25.
//

import Foundation
import AVFoundation

class AudioSessionService: ObservableObject {
    /// A Boolean indicating if the app has been granted microphone permission.
    @Published var hasPermission = false
    
    /// Controls the presentation of the alert show to the user when microphone permission has been denied.
    @Published var showingPermissionAlert = false
    
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
    
    /// The name of the currently selected input device.
    @Published var inputDeviceName: String = "Unknown Input"
    
    private var wasConfiguredForMultichannel = false
    
    init() {
        NotificationCenter.default.addObserver(self,
                       selector: #selector(handleRouteChange),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)
    }
    
    deinit {
        // Unsubscribe from the notification to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleRouteChange(notification: Notification) {
        self.configureAudioSession(isMultichannel: self.wasConfiguredForMultichannel)
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
        let currentStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch currentStatus {
        case .granted:
            print("DEBUG: Permission already granted")
            DispatchQueue.main.async {
                self.hasPermission = true
                self.configureAudioSession(isMultichannel: false)
            }
            
        case .denied:
            print("DEBUG: Permission previously denied")
            self.hasPermission = false
            self.showingPermissionAlert = true
            
        case .undetermined:
            print("DEBUG: Permission undetermined, requesting...")
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
                print("DEBUG: Permission response: \(allowed)")
                DispatchQueue.main.async {
                    if allowed {
                        self?.hasPermission = true
                        self?.configureAudioSession(isMultichannel: false)
                        
                    } else {
                        self?.hasPermission = false
                        self?.showingPermissionAlert = true
                    }
                }
            }
            
        @unknown default:
            print("DEBUG: Unknown permission status")
            self.hasPermission = false
        }
    }
    
    func configureForSimpleRecording() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                
                // Use simpler configuration for single-channel recording
                try session.setCategory(.record, mode: .default, options: [])
                try session.setActive(true)
                
                // Set to single channel
                try session.setPreferredInputNumberOfChannels(1)
                
                print("DEBUG: Audio session configured for simple recording")
                
                DispatchQueue.main.async {
                    self.updateUIWithCurrentState(session: session)
                }
                
            } catch {
                print("ERROR: Failed to configure audio session for simple recording: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.hasPermission = false
                }
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
    /// 4. Determines the number of channels to activate based on whether `isMultichannel` is true.
    /// 5. Updates its published properties on the main thread, allowing subscribers
    ///   (like a ViewModel) to receive the new hardware state.
    func configureAudioSession(isMultichannel: Bool) {
        
        if !isMultichannel {
            configureForSimpleRecording()
            return
        }
        
        self.wasConfiguredForMultichannel = isMultichannel
        
        print("DEBUG: Starting audio session configuration...")
        
        // Perform audio work on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
                try session.setActive(true)
                
                Thread.sleep(forTimeInterval: 0.2)
                
                // Find and Set the Preferred Input
                guard let preferredInput = self.selectBestAudioInput(from: session.availableInputs ?? []) else {
                    print("ERROR (SessionService): No suitable input device found.")
                    return
                }

                print("DEBUG: Found preferred input: \(preferredInput.portName) (Type: \(preferredInput.portType.rawValue))")
                try session.setPreferredInput(preferredInput)
                
                Thread.sleep(forTimeInterval: 0.1)
                
                // Configure the number of channels on the *active* input
                var desiredChannels = 1
                if isMultichannel{
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
                
                DispatchQueue.main.async {
                    self.updateUIWithCurrentState(session: session)
                }
               
            } catch {
                print("ERROR: Failed to configure audio session: \(error.localizedDescription)")
                DispatchQueue.main.async { self.hasPermission = false }
            }
        }
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
    /// for all the service's published properties like `availableChannels`, `channelNames`, and `currentInputSource`.
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
        
        if let currentInput = session.currentRoute.inputs.first, let channels = currentInput.channels, !channels.isEmpty {
            self.channelNames = channels.map { $0.channelName }
        } else if session.inputNumberOfChannels > 0 {
            self.channelNames = (1...session.inputNumberOfChannels).map { "Channel \($0)" }
        } else {
            self.channelNames = []
        }
    }
}
