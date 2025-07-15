//
//  InputSettingView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 7/2/25.
//

import SwiftUI

/// A view that contains the settings option for each audio channel.
///
/// This view acts as a container for various audio settings controls. It uses a `Form` to structure
/// the layout and provides `NavigationLink`s to other, more detailed settings views.
struct InputSettingView: View {
    
    @ObservedObject var viewModel: AudioRecordingViewModel
    let channelIndex: Int
    
    var body: some View {
        Form {
            Section(header: Text("Disable Microphone")) {
                DisableInputToggle(viewModel: viewModel, channelIndex: channelIndex)
            }
            
            Section(header: Text("Adjust Gain"), footer: Text("A gain increase to 2.00 will result in about 6dB boost in signal strength. To fully mute the microphone, use the dedicated mute toggle.")) {
                GainSliderView(viewModel: viewModel, channelIndex: channelIndex)
            }
        }
        .navigationTitle("Input Settings")
    }
}

#Preview {
    return NavigationStack {
        InputSettingView(viewModel: AudioRecordingViewModel.configuredMockViewModel(), channelIndex: 1)
    }
}
