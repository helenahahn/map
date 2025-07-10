//
//  GainSliderView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 7/10/25.
//

import SwiftUI

/// A view containing a slider that adjusts the gain level of the audio channel of choice
///
/// This view is designed to control a single channel's state. It reads the channel's current
/// gain level from the `viewModel`, and after adjustment, passes the value back into the `viewModel`
/// due to SwiftUI's two-way binding nature.
import SwiftUI

struct GainSliderView: View {
    
    @ObservedObject var viewModel: AudioRecordingViewModel
    let channelIndex: Int
    
    private var gainBinding: Binding<Float> {
        Binding<Float>(
            get: {
                guard viewModel.channelGainLevels.indices.contains(channelIndex) else {
                    return 1.0
                }
                return viewModel.channelGainLevels[channelIndex]
            },
            
            set: { newValue in
                guard viewModel.channelGainLevels.indices.contains(channelIndex) else {
                    return
                }
                viewModel.channelGainLevels[channelIndex] = newValue
            }
        )
    }
    
    var body: some View {
        Slider(value: gainBinding, in: 0...2.0)
    }
}

#Preview {
    GainSliderView(viewModel: .mockViewModel(), channelIndex: 0)
}
