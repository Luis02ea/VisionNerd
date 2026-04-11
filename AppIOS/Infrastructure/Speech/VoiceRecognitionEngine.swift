// MARK: - VoiceRecognitionEngine.swift
// GuideVision — Infrastructure Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import Speech
import AVFoundation

// MARK: - VoiceRecognitionEngine

/// Motor de reconocimiento de voz usando Speech framework.
///
/// Configura `SFSpeechRecognizer` con locale es-MX y reconocimiento
/// on-device para privacidad y menor latencia.
///
/// ## Activación
/// - Doble tap en la pantalla
/// - Botón de volumen (press largo)
///
/// ## Flujo
/// 1. El usuario activa la escucha
/// 2. Se captura audio del micrófono
/// 3. Se transcribe en tiempo real
/// 4. Se detecta silencio (fin del habla)
/// 5. Se envía el texto final al NLUParser
final class VoiceRecognitionEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Reconocedor de voz configurado para español de México.
    private let speechRecognizer: SFSpeechRecognizer?
    
    /// Solicitud de reconocimiento actual.
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// Tarea de reconocimiento activa.
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// Motor de audio para captura de micrófono.
    private let audioEngine = AVAudioEngine()
    
    /// Flag indicando si está escuchando activamente.
    private(set) var isListening: Bool = false
    
    /// Continuación del stream de texto reconocido.
    private var textContinuation: AsyncStream<RecognitionResult>.Continuation?
    
    /// Timer para detectar silencio del usuario.
    private var silenceTimer: Timer?
    
    /// Duración de silencio antes de finalizar la escucha (segundos).
    private let silenceThreshold: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    }
    
    // MARK: - Authorization
    
    /// Solicita autorización para reconocimiento de voz.
    ///
    /// - Returns: `true` si el usuario concedió acceso.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Recognition Stream
    
    /// Inicia el reconocimiento de voz y devuelve un stream de resultados.
    ///
    /// El stream emite resultados parciales durante el reconocimiento
    /// y un resultado final cuando el usuario deja de hablar.
    ///
    /// - Returns: Stream asíncrono de resultados de reconocimiento.
    /// - Throws: Error si la autorización falla o el motor no está disponible.
    func startListening() throws -> AsyncStream<RecognitionResult> {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceRecognitionError.recognizerNotAvailable
        }
        
        // Stop any existing recognition
        stopListening()
        
        let stream = AsyncStream<RecognitionResult> { [weak self] continuation in
            self?.textContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self?.stopListening()
                }
            }
        }
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // Enable on-device recognition (iOS 16+)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Tap into microphone
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.resetSilenceTimer()
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                
                self.textContinuation?.yield(
                    RecognitionResult(text: text, isFinal: isFinal)
                )
                
                if isFinal {
                    self.stopListening()
                }
            }
            
            if let error = error {
                self.textContinuation?.yield(
                    RecognitionResult(text: "", isFinal: true, error: error.localizedDescription)
                )
                self.stopListening()
            }
        }
        
        recognitionRequest = request
        isListening = true
        
        return stream
    }
    
    // MARK: - Stop Listening
    
    /// Detiene el reconocimiento de voz y libera recursos.
    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        textContinuation?.finish()
        textContinuation = nil
        
        // Restore audio session for playback
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
    }
    
    // MARK: - Silence Detection
    
    /// Reinicia el timer de detección de silencio.
    private func resetSilenceTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.silenceTimer?.invalidate()
            self?.silenceTimer = Timer.scheduledTimer(
                withTimeInterval: self?.silenceThreshold ?? 2.0,
                repeats: false
            ) { [weak self] _ in
                self?.recognitionRequest?.endAudio()
            }
        }
    }
}

// MARK: - RecognitionResult

/// Resultado del reconocimiento de voz.
struct RecognitionResult: Sendable {
    /// Texto transcrito.
    let text: String
    
    /// Indica si este es el resultado final.
    let isFinal: Bool
    
    /// Mensaje de error, si hubo alguno.
    let error: String?
    
    init(text: String, isFinal: Bool, error: String? = nil) {
        self.text = text
        self.isFinal = isFinal
        self.error = error
    }
}

// MARK: - VoiceRecognitionError

/// Errores del motor de reconocimiento de voz.
enum VoiceRecognitionError: LocalizedError {
    case recognizerNotAvailable
    case notAuthorized
    case audioEngineError(String)
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "El reconocedor de voz no está disponible para es-MX."
        case .notAuthorized:
            return "No se tiene permiso para reconocimiento de voz."
        case .audioEngineError(let detail):
            return "Error del motor de audio: \(detail)"
        }
    }
}
