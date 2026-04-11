//
//  SpeechSynthesizer.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - SpeechSynthesizer.swift
// GuideVision — Infrastructure Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import AVFoundation

// MARK: - SpeechSynthesizer

/// Motor de síntesis de voz para anuncios al usuario.
///
/// Utiliza `AVSpeechSynthesizer` con la voz "Paulina" (es-MX) por defecto
/// y una velocidad de habla ligeramente reducida para mayor claridad.
///
/// ## Características
/// - Cola de utterances para anuncios secuenciales
/// - Cancelación de utterance actual para anuncios urgentes
/// - Velocidad configurable (default: 85% de la velocidad estándar)
/// - Soporte para múltiples idiomas
///
/// ## Uso
/// ```swift
/// let synthesizer = SpeechSynthesizer()
/// await synthesizer.speak("Buscando leche. Mueve la cámara lentamente.")
/// ```
final class SpeechSynthesizer: NSObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Sintetizador de voz de AVFoundation.
    private let synthesizer = AVSpeechSynthesizer()
    
    /// Identificador de voz preferida (Paulina, es-MX).
    private let preferredVoiceIdentifier = "com.apple.voice.compact.es-MX.Paulina"
    
    /// Locale por defecto para la síntesis.
    private let defaultLocale = Locale(identifier: "es-MX")
    
    /// Velocidad de habla (85% de la velocidad estándar).
    var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.85
    
    /// Volumen de habla (0.0–1.0).
    var volume: Float = 1.0
    
    /// Flag indicando si se está hablando actualmente.
    private(set) var isSpeaking: Bool = false
    
    /// Continuación para esperar a que termine un utterance.
    private var speakingContinuation: CheckedContinuation<Void, Never>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Speech API
    
    /// Sintetiza un texto en voz alta.
    ///
    /// Si ya se está hablando, encola el utterance.
    ///
    /// - Parameters:
    ///   - text: Texto a sintetizar.
    ///   - interrupt: Si es `true`, cancela el utterance actual antes de hablar.
    func speak(_ text: String, interrupt: Bool = false) async {
        if interrupt {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = createUtterance(text: text)
        
        await withCheckedContinuation { continuation in
            speakingContinuation = continuation
            isSpeaking = true
            synthesizer.speak(utterance)
        }
    }
    
    /// Sintetiza un texto de forma no-bloqueante (fire-and-forget).
    ///
    /// - Parameters:
    ///   - text: Texto a sintetizar.
    ///   - interrupt: Si es `true`, cancela el utterance actual.
    func speakAsync(_ text: String, interrupt: Bool = false) {
        if interrupt {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = createUtterance(text: text)
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// Detiene la síntesis de voz actual.
    ///
    /// - Parameter boundary: Dónde detener — `.immediate` o `.word`.
    func stop(at boundary: AVSpeechBoundary = .immediate) {
        synthesizer.stopSpeaking(at: boundary)
        isSpeaking = false
    }
    
    /// Pausa la síntesis de voz actual.
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    /// Continúa la síntesis pausada.
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
    
    // MARK: - Utterance Creation
    
    /// Crea un utterance configurado con la voz y velocidad correctas.
    ///
    /// - Parameter text: Texto del utterance.
    /// - Returns: `AVSpeechUtterance` configurado.
    private func createUtterance(text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        
        // Try to use Paulina voice (es-MX)
        if let paulinaVoice = AVSpeechSynthesisVoice(identifier: preferredVoiceIdentifier) {
            utterance.voice = paulinaVoice
        } else if let mexicanVoice = AVSpeechSynthesisVoice(language: "es-MX") {
            utterance.voice = mexicanVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "es")
        }
        
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.pitchMultiplier = 1.0
        
        // Slight pre/post delay for natural feel
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        
        return utterance
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthesizer: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        speakingContinuation?.resume()
        speakingContinuation = nil
    }
    
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        speakingContinuation?.resume()
        speakingContinuation = nil
    }
}
