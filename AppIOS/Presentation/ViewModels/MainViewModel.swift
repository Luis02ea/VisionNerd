//
//  MainViewModel.swift
//  AppIOS
//
//  Created by Alumno on 09/04/26.
//

import Foundation
import SwiftUI


@Observable
@MainActor
final class MainViewModel {
    
    
    var searchState: SearchState = .idle
    var detectedObjects: [DetectedObject] = []
    var lastSpokenText: String = ""
    var isProcessing: Bool = false
    var errorMessage: String?
    var isCameraActive: Bool = false
    var recognizedText: String = ""
    var labelInfo: LabelInfo?
    var spatialPosition: Double = 0.5
    var currentSearchQuery: String? = nil
    
    
    private let detectObjectsUseCase: DetectObjectsUseCase
    private let searchProductUseCase: SearchProductUseCase
    private let readLabelUseCase: ReadLabelUseCase
    private let describeSceneUseCase: DescribeSceneUseCase
    
    private let speechSynthesizer: SpeechSynthesizer
    private let voiceRecognitionEngine: VoiceRecognitionEngine
    private let spatialAudioEngine: SpatialAudioEngine
    private let hapticsEngine: HapticsEngine
    private let accessibilityManager: AccessibilityManager
    
    
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
    
    
    func activateVoiceInput() {
        guard searchState == .idle || searchState == .listening else {
            handleIntent(.cancel)
            return
        }
        
        transitionState(with: .startListening)
        startListening()
    }
    
    private func startListening() {
        Task { @MainActor in
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
    
    
    private func startIdleDetection() {
        detectionTask?.cancel()
        
        detectionTask = Task { @MainActor in
            let stream = detectObjectsUseCase.execute(fps: 1)
            
            for await objects in stream {
                guard !Task.isCancelled else { break }
                self.detectedObjects = objects
            }
        }
        
        isCameraActive = true
    }
    
  
    private func startGuidedSearch(query: String) {
        currentSearchQuery = query
        transitionState(with: .intentParsed(query: query))
        
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            let stream = searchProductUseCase.startSearch(query: query)
            
            startGuidanceAnnouncements(query: query)
            
            for await objects in stream {
                guard !Task.isCancelled else { break }
                
                let matches = searchProductUseCase.filterResults(objects, for: query)
                
                if let bestMatch = matches.first {
                    transitionState(with: .objectDetected(bestMatch))
                    
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
        guidanceAnnouncementTask = Task { @MainActor in
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
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await searchProductUseCase.stopSearch()
            guidanceAnnouncementTask?.cancel()
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            transitionState(with: .reset)
            startIdleDetection()
        }
    }
    
    
    private func describeScene() {
        isProcessing = true
        
        Task { @MainActor in
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
    
    
    private func readLabel() {
        isProcessing = true
        
        Task { @MainActor in
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
    
    
    private func announceDistance() {
        Task { @MainActor in
            if let nearest = await detectObjectsUseCase.nearestObject() {
                speak("\(nearest.label) está \(nearest.estimatedDistance.localizedDescription)")
            } else {
                speak("No detecto objetos claros frente a la cámara.")
            }
        }
    }
    
    
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
    
    
    private func speak(_ text: String, interrupt: Bool = false) {
        lastSpokenText = text
        speechSynthesizer.speakAsync(text, interrupt: interrupt)
    }
}


#if DEBUG
extension MainViewModel {
    
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
