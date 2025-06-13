//
//  RecordingButtonArea.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//

import SwiftUI
import AVFoundation

struct RecordingButtonArea: View {
    
    let isRecording: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    
//    @Binding var record: Bool
//    @Binding var audioRecorder: AVAudioRecorder?
//    let hasPermission: Bool
//    let onRecordingComplete: () -> Void
//    let audioCount: Int
    
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 150)
            .overlay(
                Button(action: {
                    if isRecording {
                        onStop()
                    } else {
                        onStart()
                    }
                }) {
                    RecordingButtonIcon(isRecording: isRecording)
                }
                .offset(y: 10)
            )
    }
}

#Preview {
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
