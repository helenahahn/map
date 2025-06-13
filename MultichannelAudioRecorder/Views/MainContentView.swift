//
//  MainContentView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//

import SwiftUI

struct MainContentView: View {
    
    @Binding var recordings: [AudioRecording]
    let viewModel: AudioRecordingViewModel
    
    @EnvironmentObject private var audioPlayerService: AudioPlayerService
    
    var body: some View {
        if recordings.isEmpty {
            NoItemView()
        } else {
            List {
                ForEach(recordings) { recording in
                    DisclosureGroup (
                        content: {
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    let isThisTrackSelected = audioPlayerService.currentlyPlayingURL == recording.url
                                    let isCurrentlyPlaying = audioPlayerService.isPlaying
                                    
                                    if isThisTrackSelected && isCurrentlyPlaying {
                                        audioPlayerService.pause()
                                    } else if isThisTrackSelected && !isCurrentlyPlaying {
                                        audioPlayerService.resume()
                                    } else {
                                        audioPlayerService.play(url: recording.url)
                                    }
                                }) {
                                    let isCurrentlyPlayingThisTrack = audioPlayerService.currentlyPlayingURL == recording.url && audioPlayerService.isPlaying
                                    
                                    Image(systemName: isCurrentlyPlayingThisTrack ? "pause.fill" : "play.fill")
                                }
                                
                                Spacer()
                            }
                            .buttonStyle(.borderless)
                            .padding(.vertical, 5)
                        },
                        label: {
                            ListRowView(recording: recording)
                        }
                    )
                }
                .onDelete(perform: viewModel.delete)
            }
            .scrollContentBackground(.hidden)
        }
    }
}
    
#Preview {
    
    @State var mockRecordings = [
        AudioRecording(url: URL(fileURLWithPath: "/mock/path/Recording 1.m4a")),
        AudioRecording(url: URL(fileURLWithPath: "/mock/path/Recording 2.m4a")),
        AudioRecording(url: URL(fileURLWithPath: "/mock/path/Recording 3.m4a"))
    ]
    
    let mockViewModel = AudioRecordingViewModel()
    
    MainContentView(recordings: $mockRecordings, viewModel: mockViewModel)
    
    .environmentObject(AudioPlayerService())
}

/*
 swipeActions {
     Button("Delete") {
         viewModel.deleteRecording(recording: recording)
     }
     .tint(.red)
 }
 
 .onDelete(perform: viewModel.delete)
 */
