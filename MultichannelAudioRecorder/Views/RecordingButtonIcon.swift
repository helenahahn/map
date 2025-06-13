//
//  RecordingButtonIcon.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/8/25.
//

import SwiftUI

struct RecordingButtonIcon: View {
    let isRecording: Bool
    
    var body: some View {
        ZStack {
            Image(systemName: "mic.circle.fill")
                .resizable()
                .frame(width: 70, height: 70)
                .foregroundColor(.red)
                .padding(.bottom, 40)
            
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
