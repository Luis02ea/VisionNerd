//
//  MainViewModel.swift
//  AppIOS
//
//  Created by Alumno on 09/04/26.
//


// MARK: - MainViewModel.swift
// GuideVision — Presentation Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import SwiftUI

// MARK: - MainViewModel

/// ViewModel principal que coordina todas las funciones de GuideVision.
///
/// Orquesta los módulos de detección, búsqueda, OCR, voz y audio espacial
/// respondiendo a las intenciones del usuario (`UserIntent`).
///
/// Usa `@Observable` (iOS 17+) para reactividad automática con SwiftUI.
@Observable
@MainActor
final class MainViewModel {
    
    // MARK: - Published State
    
    /// Estado actual de la búsqueda.
    var searchState: SearchState = .idle
    
    /// Objetos detectados en el frame actual.
    var detectedObjects: [DetectedObject] = []
    
    /// Último texto hablado al usuario.
    var lastSpokenText: String = ""
    
    /// Indica si se está procesando una solicitud.
    var isProcessing: Bool = false
    
    /// Mensaje de error actual.
    var errorMessage: String?
    
    /// Indica si la cámara está activa.
    var isCameraActive: Bool = false
    
    /// Texto reconocido por voz (parcial/final).
    var recognizedText: String = ""
    
    /// Resultado de OCR (etiqueta leída).
    var labelInfo: LabelInfo?
    
    /// Posición espacial del objeto detectado (0.0 izquierda – 1.0 derecha).
    var spatialPosition: Double = 0.5
    
    /// Query de búsqueda actual (nil si no hay búsqueda activa).
    var currentSearchQuery: String? = nil
    
    // MARK: - Dependencies
    
    private let detectObjectsUseCase: DetectObjectsUseCase
    private let searchProductUseCase: SearchProductUseCase
    private let readLabelUseCase: ReadLabelUseCase
    private let describeSceneUseCase: DescribeSceneUseCase
    
    private let speechSynthesizer: SpeechSynthesizer
    private let voiceRecognitionEngine: VoiceRecognitionEngine
    private let spatialAudioEngine: SpatialAudioEngine
    private let hapticsEngine: HapticsEngine
    private let accessibilityManager: AccessibilityManager
    
    // MARK: - Tasks
    
    private var detectionTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var guidanceAnnouncementTask: Task<Void, Never>?
    
    
    init(
        detectObjectsUseCase: DetectObjectsUseCase,
        searchProductUseCase: SearchProductUseCase,
        readLabelUseCase: ReadLabelUseCase,
        describeSceneUseCase: DescribeSceneUseCase,
        speechSynthesizer: SpeechSynthesizer,
        voiceRecognitionEngine: VoiceRecognitionEngine,
        spatialAudioEngine: SpatialAudioEngine,
        hapticsEngine: HapticsEngine,
        accessibilityManager: AccessibilityManager = .shared
    ) {
        self.detectObjectsUseCase = detectObjectsUseCase
        self.searchProductUseCase = searchProductUseCase
        self.readLabelUseCase = readLabelUseCase
        self.describeSceneUseCase = describeSceneUseCase
        self.speechSynthesizer = speechSynthesizer
        self.voiceRecognitionEngine = voiceRecognitionEngine
        self.spatialAudioEngine = spatialAudioEngine
        self.hapticsEngine = hapticsEngine
        self.accessibilityManager = accessibilityManager
    }
    
    // MARK: - Lifecycle
    
    func onAppear() {
        startIdleDetection()
        spatialAudioEngine.start()
        
        speak("Bienvenido a GuideVision. Toca dos veces en la pantalla o di un comando para comenzar.")
    }
    
    func onDisappear() {
        cancelAllTasks()
        spatialAudioEngine.stop()
        hapticsEngine.stop()
    }
    
    // MARK: - Voice Activation
    
    func activateVoiceInput() {
        guard searchState == .idle || searchState == .listening else {
            handleIntent(.cancel)
            return
        }
        
        transitionState(with: .startListening)
        startListening()
    }
    
    private func startListening() {
        Task {
            let authorized = await voiceRecognitionEngine.requestAuthorization()
            guard authorized else {
                speak("No se tiene permiso para reconocimiento de voz. Actívalo en Ajustes.")
                transitionState(with: .cancel)
                return
            }
            
            do {
                let stream = try voiceRecognitionEngine.startListening()
                
                for await result in stream {
                    recognizedText = result.text
                    
                    if result.isFinal {
                        let intent = NLUParser.parse(result.text)
                        transitionState(with: .textRecognized(result.text))
                        handleIntent(intent)
                        break
                    }
                }
            } catch {
                speak("Error al escuchar: \(error.localizedDescription)")
                transitionState(with: .cancel)
            }
        }
    }
    
    // MARK: - Intent Handling
    
    func handleIntent(_ intent: UserIntent) {
        speak(intent.confirmationMessage, interrupt: true)
        
        switch intent {
        case .search(let query, _):
            startGuidedSearch(query: query)
            
        case .describeScene:
            describeScene()
            
        case .readLabel:
            readLabel()
            
        case .getDistance:
            announceDistance()
            
        case .cancel:
            cancelCurrentOperation()
            
        case .unknown:
            speak("No entendí tu solicitud. Intenta decir: buscar, leer etiqueta, o describir escena.")
            transitionState(with: .cancel)
        }
    }
    
    // MARK: - Idle Detection
    
    private func startIdleDetection() {
        detectionTask?.cancel()
        
        detectionTask = Task {
            let stream = detectObjectsUseCase.execute(fps: 1)
            
            for await objects in stream {
                guard !Task.isCancelled else { break }
                self.detectedObjects = objects
            }
        }
        
        isCameraActive = true
    }
    
    // MARK: - Guided Search (Module 4)
  
    private func startGuidedSearch(query: String) {
        currentSearchQuery = query
        transitionState(with: .intentParsed(query: query))
        
        searchTask?.cancel()
        searchTask = Task {
            let stream = searchProductUseCase.startSearch(query: query)
            
            startGuidanceAnnouncements(query: query)
            
            for await objects in stream {
                guard !Task.isCancelled else { break }
                
                let matches = searchProductUseCase.filterResults(objects, for: query)
                
                if let bestMatch = matches.first {
                    transitionState(with: .objectDetected(bestMatch))
                    
                    // Update spatial position for the audio bar
                    spatialPosition = Double(bestMatch.horizontalPosition)
                    
                    spatialAudioEngine.playSpatialAudio(for: bestMatch)
                    
                    hapticsEngine.proximityPulse(distance: bestMatch.estimatedDistance)
                    
                    if bestMatch.isVeryClose {
                        objectFound(bestMatch)
                        break
                    }
                } else {
                    transitionState(with: .noObjectFound)
                }
                
                self.detectedObjects = objects
            }
        }
    }
    
    private func startGuidanceAnnouncements(query: String) {
        guidanceAnnouncementTask?.cancel()
        guidanceAnnouncementTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                guard !Task.isCancelled else { break }
                
                switch searchState {
                case .guiding(_, let lastObject):
                    if let object = lastObject {
                        let direction = object.direction.localizedDescription
                        let distance = object.estimatedDistance.shortDescription
                        speak("Está \(direction), \(distance)")
                    } else {
                        speak("Sigo buscando \(query). Mueve la cámara.")
                    }
                case .scanning:
                    speak("Buscando \(query)... Mueve la cámara lentamente.")
                default:
                    break
                }
            }
        }
    }
    
    private func objectFound(_ object: DetectedObject) {
        spatialAudioEngine.stop()
        
        hapticsEngine.objectFound()
        
        speak("¡Llegaste! \(object.label) está justo frente a ti.", interrupt: true)
        
        transitionState(with: .objectReached(object))
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await searchProductUseCase.stopSearch()
            guidanceAnnouncementTask?.cancel()
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            transitionState(with: .reset)
            startIdleDetection()
        }
    }
    
    // MARK: - Scene Description
    
    private func describeScene() {
        isProcessing = true
        
        Task {
            do {
                let description = try await describeSceneUseCase.execute()
                speak(description)
                accessibilityManager.announce(description)
            } catch {
                speak("No pude describir la escena. \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    // MARK: - OCR / Label Reading
    
    private func readLabel() {
        isProcessing = true
        
        Task {
            do {
                speak("Analizando la etiqueta. Un momento.")
                let summary = try await readLabelUseCase.executeAndSummarize()
                speak(summary)
                accessibilityManager.announce(summary)
            } catch {
                speak("No pude leer la etiqueta. Asegúrate de que esté bien enfocada y visible.")
            }
            isProcessing = false
        }
    }
    
    // MARK: - Distance Announcement
    
    private func announceDistance() {
        Task {
            if let nearest = await detectObjectsUseCase.nearestObject() {
                speak("\(nearest.label) está \(nearest.estimatedDistance.localizedDescription)")
            } else {
                speak("No detecto objetos claros frente a la cámara.")
            }
        }
    }
    
    // MARK: - State Machine
    
    private func transitionState(with event: SearchEvent) {
        guard let newState = searchState.transition(with: event) else {
            print("[MainVM] Invalid transition from \(searchState.name) with event")
            return
        }
        
        searchState = newState
        
        if let announcement = newState.entryAnnouncement {
            accessibilityManager.announce(announcement)
        }
    }
    
    // MARK: - Cancel
    
    private func cancelCurrentOperation() {
        cancelAllTasks()
        spatialAudioEngine.stop()
        voiceRecognitionEngine.stopListening()
        
        currentSearchQuery = nil
        spatialPosition = 0.5
        
        transitionState(with: .cancel)
        speak("Operación cancelada.")
        
        startIdleDetection()
    }
    
    private func cancelAllTasks() {
        detectionTask?.cancel()
        searchTask?.cancel()
        guidanceAnnouncementTask?.cancel()
    }
    
    // MARK: - Speech Helper
    
    private func speak(_ text: String, interrupt: Bool = false) {
        lastSpokenText = text
        speechSynthesizer.speakAsync(text, interrupt: interrupt)
    }
}

// MARK: - Preview Support

#if DEBUG
extension MainViewModel {
    
    /// Creates a MainViewModel with mock dependencies for SwiftUI previews.
    static func preview(state: SearchState = .idle) -> MainViewModel {
        let cameraService = CameraService()
        let inferenceEngine = InferenceEngine()
        let cloudAIService = CloudAIService()
        
        let detectionRepo = ObjectDetectionRepositoryImpl(
            cameraService: cameraService,
            inferenceEngine: inferenceEngine
        )
        let ocrRepo = OCRRepositoryImpl(cameraService: cameraService)
        let sceneRepo = SceneDescriptionRepositoryImpl(
            inferenceEngine: inferenceEngine,
            cameraService: cameraService,
            cloudAIService: cloudAIService
        )
        
        let vm = MainViewModel(
            detectObjectsUseCase: DetectObjectsUseCase(repository: detectionRepo),
            searchProductUseCase: SearchProductUseCase(detectionRepository: detectionRepo),
            readLabelUseCase: ReadLabelUseCase(ocrRepository: ocrRepo),
            describeSceneUseCase: DescribeSceneUseCase(sceneRepository: sceneRepo),
            speechSynthesizer: SpeechSynthesizer(),
            voiceRecognitionEngine: VoiceRecognitionEngine(),
            spatialAudioEngine: SpatialAudioEngine(),
            hapticsEngine: HapticsEngine()
        )
        vm.searchState = state
        
        // Add sample data for non-idle states
        if state != .idle {
            vm.detectedObjects = [
                DetectedObject(
                    label: "Leche",
                    boundingBox: CGRect(x: 0.3, y: 0.2, width: 0.25, height: 0.3),
                    confidence: 0.94
                ),
                DetectedObject(
                    label: "Pan",
                    boundingBox: CGRect(x: 0.6, y: 0.4, width: 0.15, height: 0.18),
                    confidence: 0.87
                )
            ]
        }
        
        return vm
    }
}
#endif
