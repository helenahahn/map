//
//  SwiftUIView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//
import SwiftUI
import AVFoundation

/// The main view of the application, displaying the list of all recordings and the primary recording controls.
///
/// This view acts as the root screen within the `NavigationStack`. It observes the `AudioRecordingViewModel`
/// to display the list of recordings and to reflect the current recording state. It also presents a permission
/// alert if microphone access has been denied.
struct ListView: View {
    
    @EnvironmentObject var viewModel: AudioRecordingViewModel
    @State private var record = false
    @State private var audioRecorder: AVAudioRecorder?
    
    var body: some View {
        ZStack {
            // Main content area
            MainContentView(recordings: $viewModel.audioRecordings, viewModel: viewModel)
        
            VStack {
               Spacer()
                // The main recording button and timer area, overlaid at the bottom of the screen.
                RecordingButtonArea(
                    isRecording: viewModel.isRecording,
                    onStart: viewModel.startRecording,
                    onStop: viewModel.stopRecording
               )
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationTitle("All Recordings")
        .navigationBarItems(
            leading: EditButton(),
            trailing: NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                Image(systemName: "gearshape")
            }
        )
        .alert("Microphone Access Required", isPresented: $viewModel.showingPermissionAlert) {
            Button("Go to Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("This app needs access to your microphone to record audio. Please enable access in Settings.")
        }
        .onAppear {
            viewModel.initialize()
        }
    }
    
    
}
#Preview {
    NavigationView {
        ListView()
            .environmentObject(AudioPlayerService())
            .environmentObject(AudioRecordingViewModel.mockViewModel())
    }
}

