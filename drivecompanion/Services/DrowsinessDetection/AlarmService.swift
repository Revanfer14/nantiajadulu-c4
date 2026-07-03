//
//  AlarmService.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 03/07/26.
//

import AVFoundation

final class AlarmService {
    private var audioPlayer: AVAudioPlayer?
    private var currentSound: String?

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers]) // override silent mode
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Could not configure audio: \(error)")
        }
    }

    func play(_ soundName: String, fileExtension: String = "wav") {
        guard currentSound != soundName else { return }

        guard let url = Bundle.main.url(forResource: soundName, withExtension: fileExtension) else {
            print("Sound file not found: \(soundName).\(fileExtension)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            currentSound = soundName
        } catch {
            print("Could not play sound: \(error)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentSound = nil
    }
}
