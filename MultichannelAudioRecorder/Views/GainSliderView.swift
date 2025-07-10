//
//  GainSliderView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 7/10/25.
//

import SwiftUI

struct GainSliderView: View {
    
    @State var sliderValue = 5.0
    
    @ObservedObject var viewModel: AudioRecordingViewModel
    let channelIndex: Int
    
    var body: some View {
        Slider(value: $viewModel.channelGainLevels[channelIndex], in: 0...2.0)
    }
}

#Preview {
    GainSliderView(viewModel: .mockViewModel(), channelIndex: 0)
}
