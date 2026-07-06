//
//  DrowsinessState.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 02/07/26.
//

// MARK: Initial enum
enum DrowsinessState: String {
    case alert
    case drowsy
    case microsleep
    case noFace
}

// TODO: Add iPhone face using extension to DrowsinessState

// MARK: Watch face
extension DrowsinessState {
    var watchMascotImage: String {
            switch self {
            case .alert: return "WatchIdleMascot"
            case .drowsy: return "WatchFrownMascot"
            case .microsleep: return "WatchAngryMascot"
            case .noFace: return "WatchIdleMascot"
            }
        }
    
    var watchMascotText: String {
        switch self {
        case .alert: return "Fokus menyetir, ya."
        case .drowsy: return "Jangan merem dong!"
        case .microsleep: return "Tidak boleh tidur!"
        case .noFace: return "Fokus menyetir, ya."
        }
    }
}
