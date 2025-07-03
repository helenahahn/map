//
//  ListRowView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//
import SwiftUI

/// A view that displays a single row in the list of recordings, showing the recording's file name.
///
/// This view is designed to be used within a `List`. It takes an `AudioRecording` object and displays
/// its `fileName` property in a horizontally aligned stack.
struct ListRowView: View {
    
    /// The `AudioRecording` model object for the row being displayed.
    let recording: AudioRecording
    
    var body: some View {
        HStack {
            Text(recording.fileName)
            Spacer()
        }
    }
}

/// Provides a preview of the `ListRowView` for use in the Xcode canvas.
struct ListRowView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AudioRecording object to use for the preview.
        let mockRecording = AudioRecording(url: URL(fileURLWithPath: "First Item.m4a"))
        
        ListRowView(recording: mockRecording)
    }
}
