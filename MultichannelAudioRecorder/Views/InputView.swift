//
//  VolumeLevelView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/20/25.
//
import SwiftUI
import AVFoundation

/// A view that displays a list of the available audio inputs.
///
/// This view's behavior changes depending on whether an external audio interface is connected.
/// It uses a `Form` to display a list of navigable links for each input source.
///
/// - If more than one input device is available (e.g., an external audio interface is connected),
///   it displays a list of the individual **channels** from that interface.
/// - If only one input device is available, it displays the **name** of that device (e.g., "iPhone Microphone").
struct InputView: View {
    
    /// A reference to the shared ViewModel, which provides the list of available inputs and channels.
    @ObservedObject var viewModel: AudioRecordingViewModel
    
    var body: some View {
        Form {
            // Check if an external audio interface is likely connected.
            if viewModel.availableInputNames.count > 1 {
                ForEach(0..<viewModel.channelNames.count, id: \.self) { index in
                    NavigationLink(destination: InputSettingView(viewModel: viewModel, channelIndex: index)) {
                        Text(viewModel.channelNames[index])
                    }
                }
            } else {
                // If no, show the name of the single available device.
                ForEach(viewModel.availableInputNames, id: \.self) { name in
                    Text(name)
                }
            }
            
        }
        .navigationTitle("Available Inputs")
    }
}

/// An extension to `AudioRecordingViewModel` that provides convenience methods for creating mock data for SwiftUI Previews.
extension AudioRecordingViewModel {
    
    /// A static factory method that creates a pre-configured ViewModel instance specifically for use in SwiftUI Previews.
    ///
    /// This function initializes the ViewModel in its "preview" state, which prevents it from trying to access live hardware
    /// like the microphone. It then populates the ViewModel's properties with sample data, making it easy to see
    /// how a view will render in a specific state.
    ///
    /// - Returns: A new instance of `AudioRecordingViewModel` populated with mock data for previewing.
    static func configuredMockViewModel() -> AudioRecordingViewModel {
        let viewModel = AudioRecordingViewModel(isPreview: true)
        
        viewModel.channelNames = ["Input 1", "Input 2", "Input 3", "Input 4"]
        viewModel.enabledChannels = [true, false, true, false]
        viewModel.isMultichannelMode = true
        viewModel.availableInputNames = ["Test Channel"]
        
        return viewModel // Returns the pre-configured ViewModel instance
    }
}

#Preview {
    // The ViewModel is created and configured by the helper function before it's passed here.
    NavigationStack {
        InputView(viewModel: AudioRecordingViewModel.configuredMockViewModel())
    }
}
