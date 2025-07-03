//
//  InputSettingsView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/23/25.
//

import SwiftUI

/// A view containing a toggle switch to disable a specific audio channel.
///
/// This view is designed to control a single channel's state. It uses a custom `Binding` to
/// read the channel's current status from the `viewModel` and to call the `toggleMic()`
/// function when the user flips the switch.
struct DisableInputToggle: View {
    
    @ObservedObject var viewModel: AudioRecordingViewModel
    let channelIndex: Int
    
    var body: some View {
        
        Toggle(isOn: Binding(
            get: { !viewModel.isMicEnabled(channelIndex) },
            set: { newValue in viewModel.toggleMic(channelIndex) }
        ), label: {
            Text("Disable Microphone")
        })
        .toggleStyle(SwitchToggleStyle())
        .tint(Color.accentColor)
    }
        
}

#Preview {
    DisableInputToggle(viewModel: AudioRecordingViewModel.configuredMockViewModel(), channelIndex: 2)
}
