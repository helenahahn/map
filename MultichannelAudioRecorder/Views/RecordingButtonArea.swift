//
//  RecordingButtonArea.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//
import SwiftUI
import AVFoundation

/// A view that displays the main recording button, a timer when recording, and the gray background area.
///
/// This view is state-driven and stateless on its own. It relies on the parent view to provide the current
/// recording status and the functios to call when the record button is tapped.
struct RecordingButtonArea: View {
    
    /// A Boolean value that determines the view's appearance (e.g., showing the timer).
    /// This state is provided by the parent view.
    let isRecording: Bool
    
    /// A closure that is executed when the user taps the button to start a recording.
    let onStart: () -> Void
    
    /// A closure that is executed when the user taps the button to stop a recording.
    let onStop: () -> Void
        
    var body: some View {
        ZStack {
            // A gray rectangle that serves as the background for the control area.
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 170)
            // A container for the timer, which is only visible when `isRecording` is true.
            VStack {
                if isRecording {
                    TimerView(isRecording: isRecording)
                        .padding(.top, 105)
                }
            }
            
            // The main record/stop button.
            Button(action: {
                if isRecording {
                    onStop()
                } else {
                    onStart()
                }
            }) {
                VStack {
                    RecordingButtonIcon(isRecording: isRecording)
                }
            }
                .offset(y: 7)
        }
    }
}

#Preview {
    // A special wrapper view is needed for the preview because RecordingButtonArea
    // requires state (`isRecordingPreview`) and actions to modify that state.
    struct PreviewWrapper: View {
        @State private var isRecordingPreview = false
        
        var body: some View {
            RecordingButtonArea(
                isRecording: isRecordingPreview,
                onStart: {
                    print("Preview: Start recording")
                    isRecordingPreview = true
                },
                onStop: {
                    print("Preview: Stop recording")
                    isRecordingPreview = false
                }
            )
        }
    }
    
    return PreviewWrapper()
}
