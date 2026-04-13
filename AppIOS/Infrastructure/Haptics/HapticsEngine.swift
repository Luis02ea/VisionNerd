//
//  HapticsEngine.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

import Foundation
import UIKit
import CoreHaptics


final class HapticsEngine: @unchecked Sendable {
    

    private var coreHapticsEngine: CHHapticEngine?
    
    private let supportsHaptics: Bool
    
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    
    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        if supportsHaptics {
            setupCoreHaptics()
        }
        
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
        selectionFeedback.prepare()
    }
 
    private func setupCoreHaptics() {
        do {
            coreHapticsEngine = try CHHapticEngine()
            coreHapticsEngine?.playsHapticsOnly = true
            coreHapticsEngine?.resetHandler = { [weak self] in
                try? self?.coreHapticsEngine?.start()
            }
            try coreHapticsEngine?.start()
        } catch {
            print("[Haptics] Core Haptics setup failed: \(error)")
        }
    }
    
    
    func objectDetected() {
        lightImpact.impactOccurred(intensity: 0.5)
    }
    
    func objectNear() {
        mediumImpact.impactOccurred(intensity: 0.8)
    }
    

    func objectFound() {
        heavyImpact.impactOccurred(intensity: 1.0)
        
        if supportsHaptics {
            playCelebrationPattern()
        }
    }
    
    func error() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    func success() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func selection() {
        selectionFeedback.selectionChanged()
    }
    
 
    private func playCelebrationPattern() {
        guard let engine = coreHapticsEngine else { return }
        
        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.15
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.30
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.0,
                    duration: 0.5
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[Haptics] Failed to play celebration pattern: \(error)")
        }
    }
    
    func proximityPulse(distance: DistanceCategory) {
        switch distance {
        case .near:
            heavyImpact.impactOccurred(intensity: 1.0)
        case .medium:
            mediumImpact.impactOccurred(intensity: 0.6)
        case .far:
            lightImpact.impactOccurred(intensity: 0.3)
        }
    }
    

    func stop() {
        coreHapticsEngine?.stop()
    }
}
