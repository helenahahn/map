//
//  ItemModel.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//

import Foundation

/// Represents the data model for a single audio recording
///
/// This struct holds all the essential metadata about a recording, such as its file location, name, and creation date.
/// It conforms to the `Identifiable` protocol so that it can be used in SwiftUI's lists
struct AudioRecording: Identifiable {
    /// A stable, unique identifier for the recording instance, required by the `Identifiable` protocol.
    let id = UUID()
    
    /// The file system URL where the audio is being stored.
    let url: URL
        
    /// The name of the audio file
    var fileName: String
    
    /// The date and time of when the audio was created.
    let dateCreated: Date
    
    /// The duration of the recording in seconds.
    /// This is an optional `TimeInterval` because it might need to be calculated separately after being initialized.
    let duration: TimeInterval?
    
    /// The size of the audio file in bytes.
    /// This is an optional `Int64` as it is read from file attributes, which might not always be available.
    let fileSize: Int64?

    /// Initializes an `AudioRecording` instance by reading metadata from a file at a given URL.
    /// - Parameter url: The URL of the audio file on the file system.
    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent
        
        // Attempt to retreive the file's attributes from the file system.
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.dateCreated = attributes?[.creationDate] as? Date ?? Date()
        self.fileSize = attributes?[.size] as? Int64
        
        // Duration can be calculated later
        self.duration = nil
    }
    
    
    /// Initializes a "mock" `AudioRecording` instance with explicitly provided data.
    ///
    /// This initializer is primarily used for creating sample data for SwiftUI Previews and unit tests.
    /// - Parameters:
    ///   - mockURL: A placeholder URL for the mock recording.
    ///   - mockFileName: A placeholder file name for the mock recording.
    ///   - mockDate: The creation date for the mock recording. Defaults to the current date.
    ///   - mockDuration: The duration for the mock recording. Defaults to `nil`.
    ///   - mockFileSize: The file size for the mock recording. Defaults to `nil`.
    init(mockURL: URL, mockFileName: String, mockDate: Date = Date(), mockDuration: TimeInterval? = nil, mockFileSize: Int64? = nil) {
        self.url = mockURL
        self.fileName = mockFileName
        self.dateCreated = mockDate
        self.duration = mockDuration
        self.fileSize = mockFileSize
    }
    
    /// Provides an array of pre-configured mock recordings for testing and previewing purposes.
    /// - Returns: An array of `AudioRecording` instances containing sample data.
    static func mockRecordings() -> [AudioRecording] {
        return [
            AudioRecording(mockURL: URL(fileURLWithPath: "/mock/path/Recording_001.m4a"), mockFileName: "Recording_001.m4a", mockDate: Date().addingTimeInterval(-3600), mockDuration: 120, mockFileSize: 500 * 1024),
            AudioRecording(mockURL: URL(fileURLWithPath: "/mock/path/Recording_002.m4a"), mockFileName: "Recording_002.m4a", mockDate: Date().addingTimeInterval(-7200), mockDuration: 180, mockFileSize: 750 * 1024),
            AudioRecording(mockURL: URL(fileURLWithPath: "/mock/path/Recording_003.m4a"), mockFileName: "Recording_003.m4a", mockDate: Date().addingTimeInterval(-10800), mockDuration: 90, mockFileSize: 400 * 1024)
        ]
    }
}
