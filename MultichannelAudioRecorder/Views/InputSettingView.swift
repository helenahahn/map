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
            Section(header: Text("Audio Settings")) {
                DisableInputToggle(viewModel: viewModel, channelIndex: channelIndex)
                Text("Adjust Gain")
                Text("Test Volume Levels")
            }
        }
    }
}

#Preview {
    InputSettingView(viewModel: AudioRecordingViewModel.configuredMockViewModel(), channelIndex: 2)
}
