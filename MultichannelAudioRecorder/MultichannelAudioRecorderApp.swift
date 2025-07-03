
//  MultichannelAudioRecorderApp.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.


import SwiftUI
import SwiftData

@main
struct MultichannelAudioRecorderApp: App {
    
    @StateObject private var audioPlayerService = AudioPlayerService()
    @StateObject private var audioRecordingViewModel = AudioRecordingViewModel()

   
    var body: some Scene {
        WindowGroup {
            NavigationStack{
                ListView()
                    .onAppear {
                    audioRecordingViewModel.initialize()
                    }
            }
            .environmentObject(audioPlayerService)
            .environmentObject(audioRecordingViewModel)
        }
    }
    
}

