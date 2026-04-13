
import Foundation
import Speech
import AVFoundation


final class VoiceRecognitionEngine: @unchecked Sendable {
    
    
    private let speechRecognizer: SFSpeechRecognizer?
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    private(set) var isListening: Bool = false
    
    private var textContinuation: AsyncStream<RecognitionResult>.Continuation?
    
    private var silenceTimer: Timer?
    
    private let silenceThreshold: TimeInterval = 2.0
    
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    }
    
   
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
  
    func startListening() throws -> AsyncStream<RecognitionResult> {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceRecognitionError.recognizerNotAvailable
        }
        
        stopListening()
        
        let stream = AsyncStream<RecognitionResult> { [weak self] continuation in
            self?.textContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self?.stopListening()
                }
            }
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.resetSilenceTimer()
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                
                Task { @MainActor in
                    self.textContinuation?.yield(
                        RecognitionResult(text: text, isFinal: isFinal)
                    )
                    
                    if isFinal {
                        self.stopListening()
                    }
                }
            }
            
            if let error = error {
                Task { @MainActor in
                    self.textContinuation?.yield(
                        RecognitionResult(text: "", isFinal: true, error: error.localizedDescription)
                    )
                    self.stopListening()
                }
            }
        }
        
        recognitionRequest = request
        isListening = true
        
        return stream
    }
    
  
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
        
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
    }
 
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


struct RecognitionResult: Sendable {
    let text: String
    
    let isFinal: Bool
    
    let error: String?
    
    init(text: String, isFinal: Bool, error: String? = nil) {
        self.text = text
        self.isFinal = isFinal
        self.error = error
    }
}


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
