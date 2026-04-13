
import Foundation
import AVFoundation


@Observable
@MainActor
final class SettingsViewModel {
    
    // MARK: - Settings State
    
    var speechRate: Float {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speech_rate")
        }
    }
    
    var openAIKey: String {
        didSet {
            UserDefaults.standard.set(openAIKey, forKey: "openai_api_key")
        }
    }
    
    var anthropicKey: String {
        didSet {
            UserDefaults.standard.set(anthropicKey, forKey: "anthropic_api_key")
        }
    }
    
    var selectedProvider: String {
        didSet {
            UserDefaults.standard.set(selectedProvider, forKey: "ai_provider")
        }
    }
    
    var localOnlyMode: Bool {
        didSet {
            UserDefaults.standard.set(localOnlyMode, forKey: "local_only_mode")
        }
    }
    
    var preferredVoice: String {
        didSet {
            UserDefaults.standard.set(preferredVoice, forKey: "preferred_voice")
        }
    }
    
    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("es")
        }
    }
    
    
    init() {
        let savedSpeechRate = UserDefaults.standard.float(forKey: "speech_rate")
        self.speechRate = savedSpeechRate == 0 ? AVSpeechUtteranceDefaultSpeechRate * 0.85 : savedSpeechRate
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
