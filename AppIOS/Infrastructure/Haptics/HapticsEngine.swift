//
//  HapticsEngine.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - HapticsEngine.swift
// GuideVision — Infrastructure Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import UIKit
import CoreHaptics

// MARK: - HapticsEngine

/// Motor de retroalimentación háptica para indicar eventos al usuario.
///
/// Utiliza `UIImpactFeedbackGenerator` y `CoreHaptics` para proporcionar
/// feedback táctil que complementa el audio espacial.
///
/// ## Patrones hápticos
/// - **Objeto encontrado**: Impacto heavy + patrón de celebración
/// - **Objeto cerca**: Impacto medium
/// - **Objeto detectado**: Impacto light
/// - **Error**: Notificación de error
/// - **Éxito**: Notificación de éxito
final class HapticsEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Motor de Core Haptics para patrones avanzados.
    private var coreHapticsEngine: CHHapticEngine?
    
    /// Indica si el dispositivo soporta hápticos.
    private let supportsHaptics: Bool
    
    // MARK: - Feedback Generators
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    // MARK: - Initialization
    
    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        if supportsHaptics {
            setupCoreHaptics()
        }
        
        // Prepare all generators
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
        selectionFeedback.prepare()
    }
    
    // MARK: - Core Haptics Setup
    
    /// Configura Core Haptics para patrones avanzados.
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
    
    // MARK: - Simple Haptics
    
    /// Indica que un objeto fue detectado en el frame.
    func objectDetected() {
        lightImpact.impactOccurred(intensity: 0.5)
    }
    
    /// Indica que el objeto buscado está cerca.
    func objectNear() {
        mediumImpact.impactOccurred(intensity: 0.8)
    }
    
    /// Indica que el usuario llegó al objeto buscado.
    ///
    /// Reproduce un impacto heavy seguido de un patrón de celebración
    /// usando Core Haptics.
    func objectFound() {
        heavyImpact.impactOccurred(intensity: 1.0)
        
        // Play celebration pattern if Core Haptics is available
        if supportsHaptics {
            playCelebrationPattern()
        }
    }
    
    /// Indica un error al usuario.
    func error() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    /// Indica éxito al usuario.
    func success() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Feedback de selección sutil.
    func selection() {
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Advanced Haptic Patterns
    
    /// Reproduce un patrón háptico de celebración cuando se encuentra un objeto.
    private func playCelebrationPattern() {
        guard let engine = coreHapticsEngine else { return }
        
        do {
            let events: [CHHapticEvent] = [
                // Initial strong impact
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                // Second pulse
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.15
                ),
                // Final gentle pulse
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.30
                ),
                // Continuous soft hum
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
    
    /// Reproduce un pulso háptico de proximidad cuya intensidad varía con la distancia.
    ///
    /// - Parameter distance: Categoría de distancia del objeto.
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
    
    // MARK: - Cleanup
    
    /// Detiene el motor de Core Haptics.
    func stop() {
        coreHapticsEngine?.stop()
    }
}
