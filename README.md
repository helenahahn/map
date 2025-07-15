# **Multichannel Audio Recorder**
This iOS application is an audio recorder built with SwiftUI. It supports both standard single-channel recording and advanced multi-channel recording from external audio interfaces.

## Features
- Single and Multi-channel Recording: Seamlessly switch between recording from the device's built-in microphone or capturing multiple channels simultaneously from a connected USB audio device.
- File Management: Recordings are automatically saved and displayed in a list. Users can play back recordings and delete them with a simple swipe gesture.
- Playback Controls: An integrated audio player allows users to play, pause, and resume their recordings directly within the app.
- Dynamic UI: The user interface is built with SwiftUI and reactively updates based on the recording state, connected hardware, and permissions.
- Advanced Audio Controls: - Input Selection: The app auto-selects the best available audio input, prioritizing external hardware like USB interfaces over the built-in microphone. - Channel Management: In mult-channel mode, users can view all available input channels. - Gain Adjustment: Fine-tune the input gain for each individual channel as a slider. - Mute Channels: Unneeded channels can be individually disabled from settings.
- Permissions Handling: The app requests microphone permissions and guides the users to the settings if access is denied.
- Modern Architecture: The project follows a MVVM (Model-View-ViewModel) architecture, using Combine for reactive state management.

## How It Works
The application is structured around a central AudioRecordingViewModel that coordinates several specialized services, each responsible for a distinct piece of functionality.
- AudioRecordingViewModel: The application's central coordinator. It directs all audio-related tasks by managing the state for recording, file lists, and hardware settings. It listens for updates from the various services and provides this unified information to the SwiftUI views.
- AudioSessionService: Manages all interactions with AVAudioSession. This service is responsible for requesting permissions, discovering available hardware inputs, configuring the session for single or multi-channel recording, and selecting the best input device.
- RecordingService: Handles the logic of the actual recording process. It uses the legacy AVAudioRecorder for simple, single-channel recordings and the more powerful AVAudioEngine for complex multi-channel recordings. It also applies per=channel gain and mute settings by processing the raw audio buffers.
- AudioFileService: Responsible for all file system operations. It scans the app's documents directory for existing recordings, creates new AudioRecording models, and handles the deletion of files from disk.
- AudioPlayerService: Manages the playback of audio files. It uses AVAudioPlayer to play, pause, and resume recordings, publishing its state for the UI to observe.
- Views: The entire user interface is built with SwiftUI. Views like ListView, SettingsView, and RecordingButtonArea are driven by the state published by the AudioRecordingViewModel and AudioPlayerService.

## Code Breakdown
- MultichannelAudioRecorderApp.swift: The main entry point of the app, responsible for initializing the ViewModel and services and setting up the main WindowGroup.
- Models: 
    - AudioRecording.swift: A struct representing a single audio recording, containing metadata like its URL, creation date, and file size.
- Views: 
    - Main Views:
        - ListView.swift: The main screen of the app, displaying the list of recordings and the primary recording controls.
        - MainContentView.swift: The view that contains the list of recordings with expandable playback controls.
        - SettingsView.swift: The main settings screen, allowing the user to toggle multichannel mode and navigate to input settings.
        - NoItemView.swift: A placeholder view shown when there are no recordings.
    - Recording & Playback Views:
        - RecordingButtonArea.swift: The bottom area containing the main record/stop button and the timer.
        - RecordingButtonIcon.swift: The circular microphone icon whose appearance changes based on the recording state.
        - TimerView.swift: A view that displays an updating timer with hundredths-of-a-second precision during recording.
        - ListRowView.swift: The view for a single row in the recordings list.
    - Settings & Input Control Views:
        - InputView.swift: Displays the list of available audio inputs and their channels.
        - InputSettingView.swift: A view that contains the settings options for an individual audio channel.
        - RecordingModeToggle.swift: A toggle switch to change between single-channel and multichannel mode.
        - DisableInputToggle.swift: A toggle switch to mute or unmute a specific audio channel.
        - GainSliderView.swift: A slider to adjust the input gain for a specific audio channel.
- ViewModels: 
    - AudioRecordingViewModel.swift: The central ViewModel that connects the UI to the backend services.
- Services: 
    - RecordingService.swift: Contains the core logic for starting, stopping, and processing audio for both single and multichannel recordings. 
    - AudioSessionService.swift: Manages hardware interaction, permissions, and session configuration. 
    - AudioFileService.swift: Handles saving, fetching, and deleting audio files. 
    - AudioPlayerService.swift: Manages playback of recorded audio.

## How to Run

1. Clone the repository and open the MultichannelAudioRecorder.xcodeproj file in Xcode.
2. The app must be run on a physical iOS device as the simulator does not support audio input or external hardware.
3. To test the multi-channel features, connect a class-compliant USB audio interface to the iOS device. The app will automatically detect it and enable multi-channel mode capabilities.

## Dependencies
This project uses only native Apple frameworks:
- SwiftUI: For the user interface.
- AVFoundation: For all audio recording, playback, and session management.
- Combine: For reactive programming and state maangement between the services and the ViewModel.
