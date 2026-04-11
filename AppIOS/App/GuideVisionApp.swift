import SwiftUI
import AVFoundation
import CoreML
import Combine


@main
struct GuideVisionApp: App {
    
    // MARK: - Services
    private let cameraService = CameraService()
    private let inferenceEngine = InferenceEngine()
    private let cloudAIService = CloudAIService()
    private let spatialAudioEngine = SpatialAudioEngine()
    private let speechSynthesizer = SpeechSynthesizer()
    private let voiceRecognitionEngine = VoiceRecognitionEngine()
    private let hapticsEngine = HapticsEngine()
    
    
    private var objectDetectionRepository: ObjectDetectionRepositoryImpl {
        ObjectDetectionRepositoryImpl(
            cameraService: cameraService,
            inferenceEngine: inferenceEngine
        )
    }
    
    private var ocrRepository: OCRRepositoryImpl {
        OCRRepositoryImpl(cameraService: cameraService)
    }
    
    private var sceneDescriptionRepository: SceneDescriptionRepositoryImpl {
        SceneDescriptionRepositoryImpl(
            inferenceEngine: inferenceEngine,
            cameraService: cameraService,
            cloudAIService: cloudAIService
        )
    }
    
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainView(
                viewModel: createMainViewModel(),
                cameraService: cameraService
            )
            .onAppear {
                configureAudioSession()
                loadMLModel()
            }
        }
    }
    
    
    private func createMainViewModel() -> MainViewModel {
        let detectionRepo = objectDetectionRepository
        let ocrRepo = ocrRepository
        let sceneRepo = sceneDescriptionRepository
        
        return MainViewModel(
            detectObjectsUseCase: DetectObjectsUseCase(repository: detectionRepo),
            searchProductUseCase: SearchProductUseCase(detectionRepository: detectionRepo),
            readLabelUseCase: ReadLabelUseCase(ocrRepository: ocrRepo),
            describeSceneUseCase: DescribeSceneUseCase(sceneRepository: sceneRepo),
            speechSynthesizer: speechSynthesizer,
            voiceRecognitionEngine: voiceRecognitionEngine,
            spatialAudioEngine: spatialAudioEngine,
            hapticsEngine: hapticsEngine
        )
    }
    
   
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("[App] Error configuring audio session: \(error)")
        }
    }
    
 
    private func loadMLModel() {
        Task {
            do {
                // Try to load external CoreML model
                try await inferenceEngine.loadModel(named: "YOLOv8")
                print("[App] ✅ CoreML model loaded: YOLOv8")
                print("[App] ML Strategy: Core ML + Neural Engine")
            } catch {
                // Model not found — InferenceEngine uses Vision APIs automatically
                print("[App] ℹ️ CoreML model not found: \(error.localizedDescription)")
                print("[App] ✅ Using Vision APIs fallback:")
                print("[App]    • VNClassifyImageRequest — Scene classification (1000+ categories)")
                print("[App]    • VNDetectRectanglesRequest — Product label detection")
                print("[App]    • VNRecognizeTextRequest — OCR text recognition")
                print("[App]    • VNGenerateAttentionBasedSaliencyImageRequest — Saliency analysis")
            }
            
            // Log current ML status
            let modelInfo = await inferenceEngine.currentModelInfo
            let isNative = await inferenceEngine.isUsingNativeFallback
            print("[App] ML Engine active: \(modelInfo)")
            print("[App] Using native Vision APIs: \(isNative)")
        }
    }
}
