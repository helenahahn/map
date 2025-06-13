//
//  ItemModel.swift
//  MultichannelAudioRecorder
//
//  Created by Hwaejin Chung on 6/6/25.
//

import Foundation

struct AudioRecording: Identifiable {
    // unique identifier
    let id = UUID()
    
    // location of the audio file on the device
    let url: URL
    
    // name
    var fileName: String
    
    // data about the file
    let dateCreated: Date
    let duration: TimeInterval?
    let fileSize: Int64?
    
    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent
        
        // Get file attributes
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.dateCreated = attributes?[.creationDate] as? Date ?? Date()
        self.fileSize = attributes?[.size] as? Int64
        
        self.duration = nil
    }
}
