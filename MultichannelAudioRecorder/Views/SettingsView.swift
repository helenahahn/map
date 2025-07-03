//
//  SettingsView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/19/25.
//
import SwiftUI

/// A view that displays the main settings screen for the application.
///
/// This view acts as a container for various setting controls. It uses a `Form` to structure
/// the layout and provides `NavigationLink`s to other, more detailed settings views.
struct SettingsView: View {
    
    /// A reference to the shared ViewModel, which is passed down to the sub-views
    /// so they can read and modify the app's settings.
    @ObservedObject var viewModel: AudioRecordingViewModel
    
    var body: some View {
        Form {
            // The toggle for enabling/disabling multichannel mode.
            RecordingModeToggle(viewModel: viewModel)
            
            // A link to the view that shows input volume levels.
            NavigationLink(destination: InputView(viewModel: viewModel)) {
                Text("Inputs")
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    // Create a mock ViewModel to use for the preview.
    let mockViewModel = AudioRecordingViewModel()
    mockViewModel.isMultichannelMode = false
    
    // Embed the SettingsView in a NavigationStack to make the NavigationLink functional in the preview.
    return NavigationStack {
        SettingsView(viewModel: mockViewModel)
    }
}
