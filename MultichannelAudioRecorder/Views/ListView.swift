//
//  SwiftUIView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//

import SwiftUI
import AVFoundation

struct ListView: View {
    
    @StateObject private var viewModel: AudioRecordingViewModel
    @State private var record = false
    @State private var audioRecorder: AVAudioRecorder?
    
    init(viewModel: AudioRecordingViewModel = AudioRecordingViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Main content area
            MainContentView(recordings: $viewModel.audioRecordings, viewModel: viewModel)
        
            VStack {
               Spacer()
               RecordingButtonArea(
                   isRecording: viewModel.isRecording,
                   onStart: viewModel.startRecording,
                   onStop: viewModel.stopRecording
               )
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationTitle("All Recordings")
        .navigationBarItems(leading: EditButton())
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
    }
}

