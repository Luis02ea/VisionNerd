//
//  SpeechSynthesizer.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

import Foundation
import AVFoundation


final class SpeechSynthesizer: NSObject, @unchecked Sendable {
    

    private let synthesizer = AVSpeechSynthesizer()
    
    private let preferredVoiceIdentifier = "com.apple.voice.compact.es-MX.Paulina"
    
    private let defaultLocale = Locale(identifier: "es-MX")
    
    var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.85
    
    var volume: Float = 1.0
    
    private(set) var isSpeaking: Bool = false
    
    private var speakingContinuation: CheckedContinuation<Void, Never>?
    
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    

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
    
 
    func speakAsync(_ text: String, interrupt: Bool = false) {
        if interrupt {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = createUtterance(text: text)
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    

    func stop(at boundary: AVSpeechBoundary = .immediate) {
        synthesizer.stopSpeaking(at: boundary)
        isSpeaking = false
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
  
    private func createUtterance(text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        
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
        
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        
        return utterance
    }
}


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
