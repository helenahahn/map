//
//  AudioPlayerService.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/12/25.
//

import Foundation
import AVFoundation

class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isPlaying: Bool = false
    @Published var currentlyPlayingURL: URL?
    
    func play(url: URL) {
        if currentlyPlayingURL != url {
            stop()
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
           
            if audioPlayer == nil || currentlyPlayingURL != url {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
            }
            
            audioPlayer?.play()
            
            self.isPlaying = true
            self.currentlyPlayingURL = url
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
            self.isPlaying = false
            self.currentlyPlayingURL = nil
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        self.isPlaying = false
    }
    
    func pause() {
        audioPlayer?.pause()
        self.isPlaying = false
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isPlaying = false
        print("Audio finished playing.")
    }
}
