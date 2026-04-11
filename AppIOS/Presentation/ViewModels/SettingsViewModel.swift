// MARK: - SettingsViewModel.swift
// GuideVision — Presentation Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import AVFoundation

// MARK: - SettingsViewModel

/// ViewModel para la pantalla de ajustes de la aplicación.
///
/// Permite configurar:
/// - Velocidad de voz
/// - API key para IA en la nube
/// - Proveedor de IA preferido
/// - Modo de inferencia
@Observable
@MainActor
final class SettingsViewModel {
    
    // MARK: - Settings State
    
    /// Velocidad de habla (0.0–1.0).
    var speechRate: Float {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speech_rate")
        }
    }
    
    /// API key de OpenAI.
    var openAIKey: String {
        didSet {
            UserDefaults.standard.set(openAIKey, forKey: "openai_api_key")
        }
    }
    
    /// API key de Anthropic.
    var anthropicKey: String {
        didSet {
            UserDefaults.standard.set(anthropicKey, forKey: "anthropic_api_key")
        }
    }
    
    /// Proveedor de IA preferido.
    var selectedProvider: String {
        didSet {
            UserDefaults.standard.set(selectedProvider, forKey: "ai_provider")
        }
    }
    
    /// Usar solo inferencia local (sin nube).
    var localOnlyMode: Bool {
        didSet {
            UserDefaults.standard.set(localOnlyMode, forKey: "local_only_mode")
        }
    }
    
    /// Voz preferida para síntesis.
    var preferredVoice: String {
        didSet {
            UserDefaults.standard.set(preferredVoice, forKey: "preferred_voice")
        }
    }
    
    /// Voces disponibles en español.
    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("es")
        }
    }
    
    // MARK: - Initialization
    
    init() {
        self.speechRate = UserDefaults.standard.float(forKey: "speech_rate")
        if self.speechRate == 0 {
            self.speechRate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        }
        
        self.openAIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        self.anthropicKey = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        self.selectedProvider = UserDefaults.standard.string(forKey: "ai_provider") ?? "openai"
        self.localOnlyMode = UserDefaults.standard.bool(forKey: "local_only_mode")
        self.preferredVoice = UserDefaults.standard.string(forKey: "preferred_voice") ?? "com.apple.voice.compact.es-MX.Paulina"
    }
    
    // MARK: - Actions
    
    func resetToDefaults() {
        speechRate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        openAIKey = ""
        anthropicKey = ""
        selectedProvider = "openai"
        localOnlyMode = false
        preferredVoice = "com.apple.voice.compact.es-MX.Paulina"
    }
    
    func testVoice() {
        let utterance = AVSpeechUtterance(string: "Hola, soy GuideVision. Esta es una prueba de voz.")
        
        if let voice = AVSpeechSynthesisVoice(identifier: preferredVoice) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        }
        utterance.rate = speechRate
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}
