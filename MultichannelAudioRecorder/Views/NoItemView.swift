//
//  NoItemView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//

import SwiftUI

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
