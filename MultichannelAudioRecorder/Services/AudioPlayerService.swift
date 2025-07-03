//
//  AudioPlayerService.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/12/25.
//

import Foundation
import AVFoundation


/// A centralized service for managing audio playback throughout the app.
///
/// This class conforms to `ObservableObject` so that SwiftUI views can subscribe to its `@Published` properties
/// and update automatically when the playback state changes. It handles the lifecycle of an `AVAudioPlayer`
/// and uses the `AVAudioPlayerDelegate` to respond to events like the completion of a track.
class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    /// The private `AVAudioPlayer` instance responsible for all playback operations.
    private var audioPlayer: AVAudioPlayer?
    
    /// A Boolean value indicating whether audio is currenlty playing.
    ///
    /// This property is published to the SwiftUI environment, allowing views to react to changes in the playback state.
    @Published var isPlaying: Bool = false
    
    ///The URL of the audio file that is currently loaded or playing.
    ///
    /// This property is published to the SwiftUI environment. It helps the UI to identify which track is active.
    @Published var currentlyPlayingURL: URL?
    
    /// Begins playback of an audio file from a specified URL.
    ///
    /// If another track is already playing, it is stopped before the new track begins. This method configures the shared
    /// `AVAudioSession` for playback and handles the creation and management of the `AVAudioPlayer` instance.
    /// - Parameter url: The URL of the audio file to play.
    func play(url: URL) {
        // Checks if the user is trying to play a different track. If so, pauses the audio to prevent multiple tracks from playing simultaneously.
        if currentlyPlayingURL != url {
            stop()
        }
        
        // Configures the system's AVAudioSession. Tells iOS that the app's primary function at the time of being called is to play audio.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Creates a new player instance only if one doesn't exist or if the URL is new.
            if audioPlayer == nil || currentlyPlayingURL != url {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                // Set this class as the delegate to receive notifications, like when the audio finishes.
                audioPlayer?.delegate = self
            }
            // Start playback.
            audioPlayer?.play()
            
            // Update the published properties to notify the UI
            self.isPlaying = true
            self.currentlyPlayingURL = url
        } catch {
            // If playback fails, print the rror and reset the state.
            print("Failed to play audio: \(error.localizedDescription)")
            self.isPlaying = false
            self.currentlyPlayingURL = nil
        }
    }
    
    /// Stops audio playback completely and resets the player's postition to the beginning.
    func stop() {
        audioPlayer?.stop()
        self.isPlaying = false
    }
    
    /// Pauses the currently playing audio track.
    func pause() {
        audioPlayer?.pause()
        self.isPlaying = false
    }
    
    /// Resumes the paused audio track.
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    // MARK: AVAudioPlayerDelegate
    
    /// Delegate method called by `AVAudioPlayer` automatically when a sound has finished playing.
    ///
    /// This method is essential for updating the app's state when a track ends on its own,
    /// ensuring that the UI reflects that nothing it playing anymore.
    /// - Parameters:
    ///     - plyaer: The audio player that finished playing.
    ///     - flag: A Boolean value indicating whether playback finished successfully.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isPlaying = false
        print("Audio finished playing.")
    }
}
