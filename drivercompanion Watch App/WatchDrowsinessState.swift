//
//  WatchDrowsinessState.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 06/07/26.
//

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
