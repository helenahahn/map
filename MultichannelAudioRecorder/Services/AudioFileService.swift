//
//  AudioFileService.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 7/7/25.
//

import Foundation

class AudioFileService: ObservableObject {
    
    /// The list of all audio recordings. This property is the main data source for the UI's list view.
    @Published var audioRecordings: [AudioRecording] = []
    
    /// A Boolean that is true when the service is instantiated for SwiftUI's Previews, used to load mock data.
    private let isPreview: Bool
    
    /// A computed property that returns an array of just the URLs from the `audioRecordings` array.
    /// Useful for views that only need the file paths.
    var audioFiles: [URL] {
        return audioRecordings.map { $0.url }
    }
    
    /// A computed property that returns an array of just the file names from the `audioRecordings` array.
    var audioFileNames: [String] {
        return audioRecordings.map { $0.fileName }
    }
    
    init(isPreview: Bool = false) {
       self.isPreview = isPreview
       
       if isPreview {
           print("DEBUG: AudioFileService setting up preview data")
           self.audioRecordings = AudioRecording.mockRecordings()
       } else {
           print("DEBUG: AudioFileService initialized for real device")
           self.audioRecordings = []
       }
   }
    
    /// Scans the app's Documents directory for saved audio files and updates the `audioRecordings` array.
    ///
    /// This function ensures the user-facing list is always in sync with the files stored on disk. To prevent
    /// freezing the UI, the file I/O operations are performed on a background thread. Once the files are found
    /// and filtered (`.m4a` and `.caf`), the final update to the `@Published audioRecordings` array is dispatched
    /// back to the main thread.
    func refreshAudioFiles() {
        // Skip for previews since they use mock data
        guard !isPreview else { return }
        
        // Move file operations to background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                let result = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: .producesRelativePathURLs
                )
                print("DEBUG: Found \(result.count) files in documents directory")
                
                // Build new recordings array on background thread
                var newRecordings: [AudioRecording] = []
                
                for fileURL in result {
                    // Only add audio files
                    if fileURL.pathExtension.lowercased() == "m4a" || fileURL.pathExtension.lowercased() == "caf"{
                        let audioRecording = AudioRecording(url: fileURL)
                        newRecordings.append(audioRecording)
                    }
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Clear the array first, then populate it (matching your original logic)
                    self.audioRecordings.removeAll()
                    self.audioRecordings.append(contentsOf: newRecordings)
                    print("DEBUG: Total audio files: \(self.audioRecordings.count)")
                }
                
            } catch {
                print("DEBUG: Error reading directory: \(error.localizedDescription)")
            }
        }
    }
    
    /// Deletes audio recordings from both the user interface and the device's file system.
    ///
    /// This function performs a two-step deletion to ensure the UI feels immediately responsive.
    /// 1. The `AudioRecording` objects are instantly removed from the `@Published audioRecordings` array,
    ///    which updates the SwiftUI `List`.
    /// 2. The actual file deletion from the disk is then dispatched to a background thread to avoid
    ///    freezing the UI.
    ///
    ///- Parameter offsets: An `IndexSet` provided by SwiftUI's `.onDelete` modifier, containing the positions of the rows to be deleted.
    func delete(at offsets: IndexSet, from currentRecordings: [AudioRecording]) {
        let recordingsToDelete = offsets.map { currentRecordings[$0] }
        
        self.audioRecordings.remove(atOffsets: offsets)
        
        DispatchQueue.global(qos: .utility).async {
            for recording in recordingsToDelete {
                do {
                    try FileManager.default.removeItem(at: recording.url)
                } catch {
                    print("Error deleting the file: \(error)")
                }
            }
        }
    }
}

extension AudioFileService {
    /// A static factory method that creates and returns a pre-configured service for use in SwiftUI Previews.
    ///
    /// - Returns: A new instance of `AudioFileService` configured for previewing.
    static func mockService() -> AudioFileService {
        return AudioFileService(isPreview: true)
    }
}
