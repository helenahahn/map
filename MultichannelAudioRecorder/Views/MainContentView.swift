//
//  MainContentView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//
import SwiftUI

/// The main content view that displays either a list of audio recordings or a message if no recordings exist.
///
/// This view is responsible for the core list interface. It uses a `DisclosureGroup` for each recording
/// to reveal a playback control button. The state of this button (play/pause) is determined by observing
/// the shared `AudioPlayerService`.
struct MainContentView: View {
    
    @Binding var recordings: [AudioRecording]
    let viewModel: AudioRecordingViewModel
    
    @EnvironmentObject private var audioPlayerService: AudioPlayerService
    
    var body: some View {
        // If there are no recordings, show the placeholder view.
        if recordings.isEmpty {
            NoItemView()
                .offset(y: -40)
        } else {
            // If recordings exist, display them in a list.
            List {
                ForEach(recordings) { recording in
                    DisclosureGroup (
                        content: {
                            HStack {
                                Spacer()
                                // The master playback button for the recording.
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
                                    // The button's icon changes based on whether this specific track is currently playing.
                                    let isCurrentlyPlayingThisTrack = audioPlayerService.currentlyPlayingURL == recording.url && audioPlayerService.isPlaying
                                    
                                    Image(systemName: isCurrentlyPlayingThisTrack ? "pause.fill" : "play.fill")
                                }
                                
                                Spacer()
                            }
                            .buttonStyle(.borderless)
                            .padding(.vertical, 5)
                        },
                        label: {
                            // The main, visible part of the row.
                            ListRowView(recording: recording)
                        }
                    )
                }
                // Enables the swipe-to-delete functionality on the list.
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

