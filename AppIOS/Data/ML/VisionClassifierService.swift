// MARK: - VisionClassifierService.swift
// GuideVision — Data Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import Vision
import CoreImage
import UIKit

// MARK: - VisionClassifierService

/// Servicio de clasificación de imágenes usando las APIs nativas de Vision.
///
/// Utiliza las capacidades built-in de Vision framework que **NO requieren
/// un modelo CoreML externo**, demostrando integración funcional de ML APIs:
///
/// - `VNClassifyImageRequest` — Clasificación de escenas (1000+ categorías)
/// - `VNDetectRectanglesRequest` — Detección de rectángulos (empaques/etiquetas)
/// - `VNGenerateAttentionBasedSaliencyImageRequest` — Análisis de saliencia
/// - `VNRecognizeAnimalsRequest` — Detección de animales
///
/// ## Uso
/// ```swift
/// let service = VisionClassifierService()
/// let results = try await service.classifyScene(pixelBuffer: buffer)
/// let rectangles = try await service.detectRectangles(pixelBuffer: buffer)
/// ```
final class VisionClassifierService: @unchecked Sendable {
    
    // MARK: - Scene Classification (VNClassifyImageRequest)
    
    /// Clasifica la escena en una imagen usando el clasificador built-in de Vision.
    ///
    /// `VNClassifyImageRequest` usa un modelo de taxonomía interna de Apple
    /// entrenado con miles de categorías (animales, objetos, escenas, etc.)
    /// que corre completamente on-device sin necesidad de un modelo externo.
    ///
    /// - Parameter pixelBuffer: Frame de la cámara en formato CVPixelBuffer.
    /// - Returns: Array de clasificaciones con etiqueta y confianza,
    ///   filtradas por confianza mínima de 0.3.
    /// - Throws: Error si la clasificación falla.
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
                    
                    // Filter by minimum confidence and take top 5
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
    
    // MARK: - Rectangle Detection (VNDetectRectanglesRequest)
    
    /// Detecta rectángulos en la imagen, útil para localizar etiquetas y empaques.
    ///
    /// `VNDetectRectanglesRequest` es un modelo built-in de Vision que detecta
    /// formas rectangulares, ideal para encontrar empaques de productos,
    /// etiquetas y señalización.
    ///
    /// - Parameter pixelBuffer: Frame de la cámara.
    /// - Returns: Array de rectángulos detectados con bounding boxes normalizados.
    /// - Throws: Error si la detección falla.
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
                        // Convert from Vision coordinates (bottom-left origin) to UIKit (top-left origin)
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
                
                // Configure for product label detection
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
    
    // MARK: - Saliency Analysis (VNGenerateAttentionBasedSaliencyImageRequest)
    
    /// Analiza la saliencia de la imagen para identificar las áreas más importantes.
    ///
    /// Útil para dirigir al usuario hacia las zonas de mayor interés visual
    /// en la escena, complementando la detección de objetos.
    ///
    /// - Parameter pixelBuffer: Frame de la cámara.
    /// - Returns: Puntos de interés con su localización normalizada.
    /// - Throws: Error si el análisis falla.
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
                    
                    // Extract salient regions
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
    
    // MARK: - Combined Analysis Pipeline
    
    /// Ejecuta un pipeline completo de análisis de imagen combinando
    /// múltiples requests de Vision en una sola pasada.
    ///
    /// Esto es más eficiente que ejecutar cada request por separado
    /// porque Vision puede optimizar el preprocesamiento compartido.
    ///
    /// - Parameter pixelBuffer: Frame de la cámara.
    /// - Returns: Resultado combinado del análisis.
    /// - Throws: Error si el análisis falla.
    func runFullAnalysis(pixelBuffer: CVPixelBuffer) async throws -> FullAnalysisResult {
        try await withCheckedThrowingContinuation { continuation in
            autoreleasepool {
                var classifications: [SceneClassification] = []
                var rectangles: [DetectedRectangle] = []
                
                // Classification request
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
                
                // Rectangle detection request
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
    
    // MARK: - Label Translation
    
    /// Traduce etiquetas del clasificador de Vision (inglés) a español.
    ///
    /// Vision framework devuelve labels en inglés. Esta función proporciona
    /// traducciones para las categorías más comunes en un contexto de
    /// asistencia para personas con discapacidad visual.
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
    
    /// Identificador del clasificador (en inglés).
    let identifier: String
    
    /// Nivel de confianza (0.0–1.0).
    let confidence: VNConfidence
    
    /// Etiqueta traducida al español.
    let localizedLabel: String
    
    /// Descripción hablada para síntesis de voz.
    var spokenDescription: String {
        "\(localizedLabel) con \(Int(confidence * 100))% de confianza"
    }
}

/// Rectángulo detectado con VNDetectRectanglesRequest.
struct DetectedRectangle: Sendable, Identifiable {
    let id = UUID()
    
    /// Bounding box normalizado (coordenadas UIKit).
    let boundingBox: CGRect
    
    /// Nivel de confianza.
    let confidence: VNConfidence
    
    /// Esquinas del rectángulo (coordenadas normalizadas).
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    
    /// Área relativa del rectángulo en el frame.
    var relativeArea: CGFloat {
        boundingBox.width * boundingBox.height
    }
    
    /// Indica si el rectángulo es lo suficientemente grande para leer texto.
    var isSuitableForOCR: Bool {
        relativeArea > 0.05 && confidence > 0.6
    }
}

/// Punto de interés detectado por análisis de saliencia.
struct SaliencyPoint: Sendable {
    let boundingBox: CGRect
    let confidence: VNConfidence
}

/// Resultado combinado del pipeline de análisis completo.
struct FullAnalysisResult: Sendable {
    /// Clasificaciones de escena.
    let classifications: [SceneClassification]
    
    /// Rectángulos detectados.
    let rectangles: [DetectedRectangle]
    
    /// Timestamp del análisis.
    let timestamp: Date
    
    /// Genera una descripción hablada del análisis completo.
    var spokenDescription: String {
        var parts: [String] = []
        
        // Scene classifications
        if !classifications.isEmpty {
            let labels = classifications.prefix(3).map(\.localizedLabel)
            parts.append("Veo: \(labels.joined(separator: ", "))")
        }
        
        // Rectangle count (potential product labels)
        if !rectangles.isEmpty {
            let ocrSuitable = rectangles.filter(\.isSuitableForOCR).count
            if ocrSuitable > 0 {
                parts.append("Detecto \(ocrSuitable) etiqueta\(ocrSuitable == 1 ? "" : "s") legible\(ocrSuitable == 1 ? "" : "s")")
            }
        }
        
        return parts.isEmpty ? "No detecto elementos claros" : parts.joined(separator: ". ")
    }
}

// MARK: - VisionServiceError

/// Errores del servicio de clasificación de Vision.
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
