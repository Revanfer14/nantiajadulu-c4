//
//  DrowsinessMonitor.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 03/07/26.
//

import Foundation
import Combine

final class DrowsinessMonitor: ObservableObject {
    @Published private(set) var state: DrowsinessState = .noFace
    @Published private(set) var perclos: Double = 0
    @Published private(set) var closedDuration: TimeInterval = 0

    func update(state: DrowsinessState, perclos: Double, closedDuration: TimeInterval) {
        self.state = state
        self.perclos = perclos
        self.closedDuration = closedDuration
    }
}
