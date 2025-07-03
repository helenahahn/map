//
//  RecordingModeToggle.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/19/25.
//
import SwiftUI

/// A view containing a toggle switch that controls the app's recording mode (single-channel vs. multichannel).
///
/// This view directly manipulates the `isMultichannelMode` property on the `AudioRecordingViewModel`.
/// It is designed to be used within a `Form` or `List` in the app's settings.
struct RecordingModeToggle: View {
    
    @ObservedObject private var viewModel: AudioRecordingViewModel
    
    init(viewModel: AudioRecordingViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        
        Toggle(isOn: $viewModel.isMultichannelMode, label: {
            Text("Multichannel Mode")
        })
        .toggleStyle(SwitchToggleStyle())
        .tint(Color.accentColor)
    }
}

#Preview {
    let mockViewModel = AudioRecordingViewModel()
    mockViewModel.isMultichannelMode = true
    return RecordingModeToggle(viewModel: mockViewModel)
}
