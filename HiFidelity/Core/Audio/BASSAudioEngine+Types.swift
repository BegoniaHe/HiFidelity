//  BASSAudioEngine+Types.swift
//  HiFidelity
//
//  Supporting types for BASSAudioEngine
//

import Foundation

// MARK: - Delegate Protocol

protocol BASSAudioEngineDelegate: AnyObject {
    func audioEngine(_ engine: BASSAudioEngine, didUpdateTime time: Double)
    func audioEngineDidFinishPlaying(_ engine: BASSAudioEngine)
}

// MARK: - Stream Info

struct BASSStreamInfo {
    let frequency: Int
    let channels: Int
    let bitrate: Int
    let bitDepth: Int
}

// MARK: - BASS Error Codes

enum BASSError: Int {
    case ok = 0
    case mem = 1
    case fileOpen = 2
    case driver = 3
    case bufLost = 4
    case handle = 5
    case format = 6
    case position = 7
    case initialization = 8
    case start = 9
    case already = 14
    case notAvail = 18
    case decode = 19
    case dx = 20
    case timeout = 21
    case fileForm = 23
    case speaker = 24
    case version = 25
    case codec = 26
    case ended = 27
    case busy = 28
    case unknown = -1

    var description: String {
        switch self {
        case .ok: return "All is OK"
        case .mem: return "Memory error"
        case .fileOpen: return "Cannot open the file"
        case .driver: return "Cannot find a free/valid driver"
        case .bufLost: return "Sample buffer was lost"
        case .handle: return "Invalid handle"
        case .format: return "Unsupported sample format"
        case .position: return "Invalid position"
        case .initialization: return "BASS_Init has not been successfully called"
        case .start: return "BASS_Start has not been successfully called"
        case .already: return "Already initialized/started"
        case .notAvail: return "Not available"
        case .decode: return "Channel is not a 'decoding channel'"
        case .dx: return "DirectX not available"
        case .timeout: return "Timeout"
        case .fileForm: return "Unsupported file format"
        case .speaker: return "Invalid speaker config"
        case .version: return "Invalid BASS version"
        case .codec: return "Codec not available"
        case .ended: return "Stream has ended"
        case .busy: return "Device is busy"
        case .unknown: return "Unknown error"
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let bassStreamEnded = Notification.Name("BASSStreamEnded")
    static let bassGaplessTransition = Notification.Name("BASSGaplessTransition")
    static let streamInfoDidUpdate = Notification.Name("StreamInfoDidUpdate")
}
