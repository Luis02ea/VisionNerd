
import Foundation
import Vision
import CoreImage
import UIKit


final class VisionClassifierService: @unchecked Sendable {
    

    func classifyScene(pixelBuffer: CVPixelBuffer) async throws -> [SceneClassification] {
        try await withCheckedThrowingContinuation { continuation in
            autoreleasepool {
                let request = VNClassifyImageRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: VisionServiceError.classificationFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let results = request.results as? [VNClassificationObservation] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let classifications = results
                        .filter { $0.confidence >= 0.3 }
                        .prefix(5)
                        .map { observation in
                            SceneClassification(
                                identifier: observation.identifier,
                                confidence: observation.confidence,
                                localizedLabel: Self.translateLabel(observation.identifier)
                            )
                        }
                    
                    continuation.resume(returning: Array(classifications))
                }
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionServiceError.classificationFailed(error.localizedDescription))
                }
            }
        }
    }
    

    func detectRectangles(pixelBuffer: CVPixelBuffer) async throws -> [DetectedRectangle] {
        try await withCheckedThrowingContinuation { continuation in
            autoreleasepool {
                let request = VNDetectRectanglesRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: VisionServiceError.rectangleDetectionFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let results = request.results as? [VNRectangleObservation] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let rectangles = results.map { observation in
                        let boundingBox = CGRect(
                            x: observation.boundingBox.origin.x,
                            y: 1.0 - observation.boundingBox.origin.y - observation.boundingBox.height,
                            width: observation.boundingBox.width,
                            height: observation.boundingBox.height
                        )
                        
                        return DetectedRectangle(
                            boundingBox: boundingBox,
                            confidence: observation.confidence,
                            topLeft: observation.topLeft,
                            topRight: observation.topRight,
                            bottomLeft: observation.bottomLeft,
                            bottomRight: observation.bottomRight
                        )
                    }
                    
                    continuation.resume(returning: rectangles)
                }
                
                request.minimumAspectRatio = 0.2
                request.maximumAspectRatio = 1.0
                request.minimumSize = 0.1
                request.maximumObservations = 5
                request.minimumConfidence = 0.5
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionServiceError.rectangleDetectionFailed(error.localizedDescription))
                }
            }
        }
    }
    
 
    func analyzeSaliency(pixelBuffer: CVPixelBuffer) async throws -> [SaliencyPoint] {
        try await withCheckedThrowingContinuation { continuation in
            autoreleasepool {
                let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: VisionServiceError.saliencyFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let results = request.results as? [VNSaliencyImageObservation],
                          let saliency = results.first else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let points = (saliency.salientObjects ?? []).map { region in
                        SaliencyPoint(
                            boundingBox: CGRect(
                                x: region.boundingBox.origin.x,
                                y: 1.0 - region.boundingBox.origin.y - region.boundingBox.height,
                                width: region.boundingBox.width,
                                height: region.boundingBox.height
                            ),
                            confidence: region.confidence
                        )
                    }
                    
                    continuation.resume(returning: points)
                }
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionServiceError.saliencyFailed(error.localizedDescription))
                }
            }
        }
    }
    

    func runFullAnalysis(pixelBuffer: CVPixelBuffer) async throws -> FullAnalysisResult {
        try await withCheckedThrowingContinuation { continuation in
            autoreleasepool {
                var classifications: [SceneClassification] = []
                var rectangles: [DetectedRectangle] = []
                
                let classifyRequest = VNClassifyImageRequest { request, _ in
                    if let results = request.results as? [VNClassificationObservation] {
                        classifications = results
                            .filter { $0.confidence >= 0.3 }
                            .prefix(5)
                            .map { SceneClassification(
                                identifier: $0.identifier,
                                confidence: $0.confidence,
                                localizedLabel: Self.translateLabel($0.identifier)
                            )}
                    }
                }
                
                let rectRequest = VNDetectRectanglesRequest { request, _ in
                    if let results = request.results as? [VNRectangleObservation] {
                        rectangles = results.map { obs in
                            DetectedRectangle(
                                boundingBox: CGRect(
                                    x: obs.boundingBox.origin.x,
                                    y: 1.0 - obs.boundingBox.origin.y - obs.boundingBox.height,
                                    width: obs.boundingBox.width,
                                    height: obs.boundingBox.height
                                ),
                                confidence: obs.confidence,
                                topLeft: obs.topLeft,
                                topRight: obs.topRight,
                                bottomLeft: obs.bottomLeft,
                                bottomRight: obs.bottomRight
                            )
                        }
                    }
                }
                rectRequest.minimumAspectRatio = 0.2
                rectRequest.maximumAspectRatio = 1.0
                rectRequest.minimumSize = 0.1
                rectRequest.maximumObservations = 5
                
                // Execute all requests in a single handler pass
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([classifyRequest, rectRequest])
                    
                    let result = FullAnalysisResult(
                        classifications: classifications,
                        rectangles: rectangles,
                        timestamp: Date()
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: VisionServiceError.analysisFailed(error.localizedDescription))
                }
            }
        }
    }
    

    static func translateLabel(_ englishLabel: String) -> String {
        let translations: [String: String] = [
            // Objetos cotidianos
            "bottle": "botella", "cup": "taza", "chair": "silla",
            "table": "mesa", "door": "puerta", "person": "persona",
            "car": "auto", "book": "libro", "phone": "teléfono",
            "laptop": "computadora portátil", "keyboard": "teclado",
            "tv": "televisor", "monitor": "monitor", "clock": "reloj",
            "bag": "bolsa", "backpack": "mochila", "umbrella": "paraguas",
            "shoe": "zapato", "hat": "sombrero", "glasses": "lentes",
            
            // Alimentos
            "food": "comida", "fruit": "fruta", "vegetable": "verdura",
            "bread": "pan", "milk": "leche", "water": "agua",
            "apple": "manzana", "banana": "plátano", "orange": "naranja",
            "meat": "carne", "rice": "arroz", "egg": "huevo",
            
            // Escenas
            "indoor": "interior", "outdoor": "exterior",
            "kitchen": "cocina", "bathroom": "baño",
            "bedroom": "recámara", "living room": "sala",
            "store": "tienda", "supermarket": "supermercado",
            "street": "calle", "park": "parque", "office": "oficina",
            
            // Animales
            "dog": "perro", "cat": "gato", "bird": "pájaro",
            
            // Muebles
            "couch": "sofá", "bed": "cama", "shelf": "estante",
            "desk": "escritorio", "cabinet": "gabinete",
            
            // Señalización
            "sign": "letrero", "text": "texto", "label": "etiqueta"
        ]
        
        return translations[englishLabel.lowercased()] ?? englishLabel
    }
}

// MARK: - Result Types

/// Resultado de clasificación de escena usando VNClassifyImageRequest.
struct SceneClassification: Sendable, Identifiable {
    let id = UUID()
    let identifier: String
    let confidence: VNConfidence
    let localizedLabel: String
    var spokenDescription: String {
        "\(localizedLabel) con \(Int(confidence * 100))% de confianza"
    }
}

struct DetectedRectangle: Sendable, Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    let confidence: VNConfidence
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    var relativeArea: CGFloat {
        boundingBox.width * boundingBox.height
    }
    
    var isSuitableForOCR: Bool {
        relativeArea > 0.05 && confidence > 0.6
    }
}

struct SaliencyPoint: Sendable {
    let boundingBox: CGRect
    let confidence: VNConfidence
}

struct FullAnalysisResult: Sendable {
    let classifications: [SceneClassification]
    let rectangles: [DetectedRectangle]
    let timestamp: Date
    var spokenDescription: String {
        var parts: [String] = []
        
        if !classifications.isEmpty {
            let labels = classifications.prefix(3).map(\.localizedLabel)
            parts.append("Veo: \(labels.joined(separator: ", "))")
        }
        
            if !rectangles.isEmpty {
            let ocrSuitable = rectangles.filter(\.isSuitableForOCR).count
            if ocrSuitable > 0 {
                parts.append("Detecto \(ocrSuitable) etiqueta\(ocrSuitable == 1 ? "" : "s") legible\(ocrSuitable == 1 ? "" : "s")")
            }
        }
        
        return parts.isEmpty ? "No detecto elementos claros" : parts.joined(separator: ". ")
    }
}

enum VisionServiceError: LocalizedError {
    case classificationFailed(String)
    case rectangleDetectionFailed(String)
    case saliencyFailed(String)
    case analysisFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .classificationFailed(let d): return "Clasificación fallida: \(d)"
        case .rectangleDetectionFailed(let d): return "Detección de rectángulos fallida: \(d)"
        case .saliencyFailed(let d): return "Análisis de saliencia fallido: \(d)"
        case .analysisFailed(let d): return "Análisis completo fallido: \(d)"
        }
    }
}
