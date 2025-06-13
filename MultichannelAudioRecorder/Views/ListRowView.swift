//
//  ListRowView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//

import SwiftUI

struct ListRowView: View {
    
    let recording: AudioRecording
    
    var body: some View {
        HStack {
            Text(recording.fileName)
            Spacer()
        }
    }
}

struct ListRowView_Previews: PreviewProvider {
    static var previews: some View {
        let mockRecording = AudioRecording(url: URL(fileURLWithPath: "First Item.m4a"))
        
        ListRowView(recording: mockRecording)
    }
}
