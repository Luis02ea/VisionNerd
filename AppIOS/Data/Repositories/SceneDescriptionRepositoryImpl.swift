import Foundation
import UIKit


final class SceneDescriptionRepositoryImpl: SceneDescriptionRepository, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let inferenceEngine: InferenceEngine
    private let cameraService: CameraService
    private let cloudAIService: CloudAIService
    private let visionClassifier: VisionClassifierService
        
    init(
        inferenceEngine: InferenceEngine,
        cameraService: CameraService,
        cloudAIService: CloudAIService,
        visionClassifier: VisionClassifierService = VisionClassifierService()
    ) {
        self.inferenceEngine = inferenceEngine
        self.cameraService = cameraService
        self.cloudAIService = cloudAIService
        self.visionClassifier = visionClassifier
    }
        
    func describeCurrentScene() async throws -> String {
        guard let pixelBuffer = cameraService.captureSnapshot() else {
            throw SceneDescriptionError.noFrameAvailable
        }
        
        let visionAnalysis = try? await visionClassifier.runFullAnalysis(pixelBuffer: pixelBuffer)
        let detectedObjects = try? await inferenceEngine.detectObjects(in: pixelBuffer)
        let hasGoodLocalResults = (detectedObjects?.count ?? 0) >= 2 ||
                                  (visionAnalysis?.classifications.count ?? 0) >= 2
        
        if hasGoodLocalResults {
            return buildCombinedDescription(
                objects: detectedObjects ?? [],
                analysis: visionAnalysis
            )
        }
        
        if cloudAIService.isConnected {
            if let imageData = pixelBufferToJPEG(pixelBuffer) {
                do {
                    return try await cloudAIService.describeScene(imageData: imageData)
                } catch {
                }
            }
        }
        
        return buildCombinedDescription(
            objects: detectedObjects ?? [],
            analysis: visionAnalysis
        )
    }
    
    func describeLocally(objects: [DetectedObject]) -> String {
        buildCombinedDescription(objects: objects, analysis: nil)
    }
    
    func describeWithCloudAI(imageData: Data) async throws -> String {
        try await cloudAIService.describeScene(imageData: imageData)
    }
    
 
    private func buildCombinedDescription(
        objects: [DetectedObject],
        analysis: FullAnalysisResult?
    ) -> String {
        var parts: [String] = []
        
        if let classifications = analysis?.classifications, !classifications.isEmpty {
            let labels = classifications.prefix(3).map(\.localizedLabel)
            parts.append("La escena parece ser: \(labels.joined(separator: ", "))")
        }
        
        if !objects.isEmpty {
            parts.append("Detecto \(objects.count) objeto\(objects.count == 1 ? "" : "s")")
            
            let leftObjects = objects.filter { $0.direction == .left }
            let centerObjects = objects.filter { $0.direction == .center }
            let rightObjects = objects.filter { $0.direction == .right }
            
            if !leftObjects.isEmpty {
                let names = leftObjects.map { "\($0.label) \($0.estimatedDistance.shortDescription)" }
                parts.append("A la izquierda: \(names.joined(separator: ", "))")
            }
            
            if !centerObjects.isEmpty {
                let names = centerObjects.map { "\($0.label) \($0.estimatedDistance.shortDescription)" }
                parts.append("Al centro: \(names.joined(separator: ", "))")
            }
            
            if !rightObjects.isEmpty {
                let names = rightObjects.map { "\($0.label) \($0.estimatedDistance.shortDescription)" }
                parts.append("A la derecha: \(names.joined(separator: ", "))")
            }
            
            if let nearest = objects.min(by: { $0.boundingBox.height > $1.boundingBox.height }) {
                parts.append("Lo más cerca es \(nearest.label)")
            }
        }
        
        if let rectangles = analysis?.rectangles, !rectangles.isEmpty {
            let ocrSuitable = rectangles.filter(\.isSuitableForOCR).count
            if ocrSuitable > 0 {
                parts.append("Detecto \(ocrSuitable) etiqueta\(ocrSuitable == 1 ? "" : "s") que podría\(ocrSuitable == 1 ? "" : "n") leerse")
            }
        }
        
        if parts.isEmpty {
            return "No detecto objetos claros en la escena actual. Intenta mover la cámara lentamente."
        }
        
        return parts.joined(separator: ". ") + "."
    }
        
    private func pixelBufferToJPEG(_ pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    }
}

enum SceneDescriptionError: LocalizedError {
    case noFrameAvailable
    case descriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .noFrameAvailable:
            return "No hay frame disponible para describir la escena."
        case .descriptionFailed:
            return "No se pudo generar una descripción de la escena."
        }
    }
}
