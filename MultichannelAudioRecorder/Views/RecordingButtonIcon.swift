//
//  RecordingButtonIcon.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//
import SwiftUI

/// A view that displays the main circular microphone icon for the record button.
///
/// This view is purely presentational. Its appearance changes based on the `isRecording`
/// property to provide visual feedback to the user. When `isRecording` is true, a white
/// outer ring is drawn around the icon.
struct RecordingButtonIcon: View {
    /// A Boolean provided by the parent view that determines whether to show the "recording" state.
    let isRecording: Bool
    
    var body: some View {
        ZStack {
            // The base microphone icon.
            Image(systemName: "mic.circle.fill")
                .resizable()
                .frame(width: 70, height: 70)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor)
                .padding(.bottom, 40)
            
            // The white circle shown only during recording.
            if isRecording {
                Circle()
                    .stroke(Color.white, lineWidth: 6)
                    .frame(width: 85, height: 85)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    RecordingButtonIcon(isRecording: true)
}
