//
//  NoItemView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//
import SwiftUI

/// The default message shown to the user.
///
/// This message is displayed only when there are no recordings on file.
struct NoItemView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Tap the record button to start recording.")
                .font(.body)
                .fontWeight(.regular)
                .foregroundColor(Color.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NoItemView()
}
