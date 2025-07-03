//
//  TimerView.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/20/25.
//
import SwiftUI

/// A view that displays an updating timer with hundredths-of-a-second precision.
///
/// This view's timer is controlled by the `isRecording` property. When `isRecording` becomes true,
/// the view starts a `Timer` to update its internal time state. When `isRecording` is false, the
/// timer is stopped and reset.
struct TimerView: View {
    
    /// The internal state that tracks the elapsed time in seconds.
    @State private var time = 0.0
    
    /// The `Timer` object that repeatedly fires to update the `time` property.
    /// This is an optional because the timer is not always active.
    @State private var timer: Timer?
    
    /// A Boolean provided by the parent view that controls the timer's state.
    let isRecording: Bool
    
    /// A computed property that formats the `time` state into a "HH:MM:SS.ss" string.
    private var formattedTime: String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let hundredths = Int((time - Double(totalSeconds)) * 100)

        return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, hundredths)
    }
    
    var body: some View {
        Text(String(formattedTime))
            .bold()
            .monospacedDigit()
        
            // The `.onAppear` modifier is used to start or stop the timer
            // when the view is first displayed.
            .onAppear {
                if isRecording {
                    startTimer()
                } else {
                    stopTimer()
                }
            }
    }
    
    /// Creates and starts a new timer that increments the `time` state every 0.01 seconds.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            time += 0.01
        }
    }
    
    /// Stops and invalidates the active timer.
    private func stopTimer() {
        timer?.invalidate()
        resetTime()
    }
    
    /// Resets the `time` state back to zero.
    private func resetTime() {
        time = 0.0
    }
}

#Preview {
    let testIsRecording: Bool = false
    TimerView(isRecording: testIsRecording)
}
