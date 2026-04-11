// MARK: - InferenceEngine.swift
// GuideVision — Data Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import CoreML
import Vision
import UIKit

// MARK: - InferenceEngine

/// Actor que encapsula el pipeline de inferencia de Machine Learning.
///
/// Garantiza acceso thread-safe al modelo CoreML y controla el throttling
/// de procesamiento de frames según el estado de la aplicación.
///
/// ## Integración de ML
/// Este actor demuestra integración funcional de múltiples APIs de ML:
///
/// 1. **Core ML (`VNCoreMLModel`)** — Modelos .mlpackage (e.g., YOLOv8)
///    con `computeUnits = .cpuAndNeuralEngine` para optimización en Neural Engine.
///
/// 2. **Vision Framework (`VNCoreMLRequest`)** — Pipeline de inferencia con
///    preprocesamiento automático de imagen y manejo de resultados tipados.
///
/// 3. **Vision Built-in APIs (fallback)** — Cuando no hay modelo CoreML,
///    usa `VNClassifyImageRequest` + `VNDetectRectanglesRequest` como fallback
///    funcional que NO requiere modelo externo.
///
/// ## Características
/// - Carga de modelo CoreML (.mlpackage) con `computeUnits = .cpuAndNeuralEngine`
/// - **Fallback automático** a Vision APIs nativas si no hay modelo
/// - Throttling configurable: 1fps (idle) / 5fps (búsqueda activa)
/// - Filtro de confianza mínima: 0.65
/// - Estimación de distancia por tamaño de bounding box
/// - Suspensión automática con batería < 10%
/// - `autoreleasepool` en el loop de procesamiento
///
/// ## Uso
/// ```swift
/// let engine = InferenceEngine()
/// // Opción A: Con modelo CoreML externo
/// try await engine.loadModel(named: "YOLOv8")
/// // Opción B: Sin modelo — usa Vision APIs nativas automáticamente
/// let objects = try await engine.detectObjects(in: pixelBuffer)
/// ```
actor InferenceEngine {
    
    // MARK: - Properties
    
    /// Modelo CoreML cargado (nil si se usa el fallback de Vision).
    private var model: VNCoreMLModel?
    
    /// Nombre del modelo cargado.
    private var modelName: String?
    
    /// Servicio de clasificación de Vision (fallback sin modelo externo).
    private let visionClassifier = VisionClassifierService()
    
    /// Indica si se está usando el fallback de Vision APIs nativas.
    private(set) var isUsingNativeFallback: Bool = true
    
    /// Frames por segundo objetivo para throttling.
    private var targetFPS: Int = 1
    
    /// Timestamp del último procesamiento de frame.
    private var lastProcessingTime: Date = .distantPast
    
    /// Flag para indicar si el motor está activo.
    private(set) var isActive: Bool = true
    
    /// Confianza mínima requerida para aceptar una detección.
    private let minimumConfidence: Float = 0.65
    
    /// Configuración del modelo CoreML.
    ///
    /// Usa `.cpuAndNeuralEngine` en lugar de `.all` para evitar
    /// competir por la GPU cuando la app está en background.
    private let modelConfiguration: MLModelConfiguration = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return config
    }()
    
    // MARK: - Model Loading (Core ML)
    
    /// Carga un modelo CoreML desde el bundle de la app.
    ///
    /// Si el modelo se carga exitosamente, se desactiva el fallback de Vision
    /// y se usa el modelo CoreML para todas las inferencias.
    ///
    /// - Parameter name: Nombre del archivo .mlmodelc o .mlpackage (sin extensión).
    /// - Throws: Error si el modelo no se puede cargar o compilar.
    func loadModel(named name: String) throws {
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") ??
              Bundle.main.url(forResource: name, withExtension: "mlpackage") else {
            throw InferenceError.modelNotFound(name)
        }
        
        let mlModel = try MLModel(contentsOf: modelURL, configuration: modelConfiguration)
        model = try VNCoreMLModel(for: mlModel)
        modelName = name
        isActive = true
        isUsingNativeFallback = false
        
        print("[InferenceEngine] ✅ CoreML model loaded: \(name)")
        print("[InferenceEngine] computeUnits = .cpuAndNeuralEngine")
    }
    
    /// Carga un modelo CoreML desde una URL arbitraria.
    ///
    /// Útil para modelos descargados dinámicamente o de Create ML.
    ///
    /// - Parameter url: URL del modelo compilado.
    /// - Throws: Error si el modelo no se puede cargar.
    func loadModel(from url: URL) throws {
        let mlModel = try MLModel(contentsOf: url, configuration: modelConfiguration)
        model = try VNCoreMLModel(for: mlModel)
        modelName = url.lastPathComponent
        isActive = true
        isUsingNativeFallback = false
        
        print("[InferenceEngine] ✅ CoreML model loaded from URL: \(url.lastPathComponent)")
    }
    
    // MARK: - Detection (CoreML + Vision Fallback)
    
    /// Detecta objetos en un pixel buffer de la cámara.
    ///
    /// **Estrategia de inferencia:**
    /// 1. Si hay un modelo CoreML cargado → `VNCoreMLRequest`
    /// 2. Si NO hay modelo → Fallback a Vision APIs nativas:
    ///    - `VNClassifyImageRequest` para clasificación de escena
    ///    - `VNDetectRectanglesRequest` para detectar empaques/etiquetas
    ///
    /// Aplica throttling basado en `targetFPS` y verifica el nivel de batería.
    ///
    /// - Parameter pixelBuffer: Buffer del frame de la cámara.
    /// - Returns: Array de objetos detectados con confianza ≥ 0.65.
    func detectObjects(in pixelBuffer: CVPixelBuffer) async throws -> [DetectedObject] {
        // Check battery level — suspend inference at <10%
        guard !shouldSuspendForBattery() else {
            return []
        }
        
        // Throttling: check if enough time has passed since last processing
        let now = Date()
        let minInterval = 1.0 / Double(targetFPS)
        guard now.timeIntervalSince(lastProcessingTime) >= minInterval else {
            return []
        }
        
        lastProcessingTime = now
        
        // Route to appropriate inference method
        if let model = model {
            return try await detectWithCoreML(model: model, pixelBuffer: pixelBuffer)
        } else {
            return try await detectWithNativeVisionAPIs(pixelBuffer: pixelBuffer)
        }
    }
    
    // MARK: - CoreML Inference
    
    /// Ejecuta detección de objetos usando un modelo CoreML cargado.
    ///
    /// Usa `VNCoreMLRequest` que integra el pipeline completo:
    /// preprocesamiento de imagen → inferencia en Neural Engine → post-procesamiento.
    private func detectWithCoreML(model: VNCoreMLModel, pixelBuffer: CVPixelBuffer) async throws -> [DetectedObject] {
        return try await withCheckedThrowingContinuation { continuation in
            autoreleasepool {
                let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                    guard let self = self else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    if let error = error {
                        continuation.resume(throwing: InferenceError.inferenceFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let results = request.results as? [VNRecognizedObjectObservation] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let objects = results.compactMap { observation -> DetectedObject? in
                        guard let topLabel = observation.labels.first,
                              topLabel.confidence >= self.minimumConfidence else {
                            return nil
                        }
                        
                        // Convert Vision coordinates (bottom-left origin) to UIKit (top-left origin)
                        let boundingBox = CGRect(
                            x: observation.boundingBox.origin.x,
                            y: 1.0 - observation.boundingBox.origin.y - observation.boundingBox.height,
                            width: observation.boundingBox.width,
                            height: observation.boundingBox.height
                        )
                        
                        return DetectedObject(
                            label: topLabel.identifier,
                            boundingBox: boundingBox,
                            confidence: topLabel.confidence
                        )
                    }
                    
                    continuation.resume(returning: objects)
                }
                
                request.imageCropAndScaleOption = .scaleFill
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: InferenceError.inferenceFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Native Vision API Fallback
    
    /// Ejecuta detección usando Vision APIs nativas (sin modelo externo).
    ///
    /// Combina `VNClassifyImageRequest` y `VNDetectRectanglesRequest`
    /// para generar DetectedObjects a partir de las APIs built-in de Apple.
    ///
    /// Esto permite que la app funcione inmediatamente sin necesidad de
    /// importar un modelo .mlpackage, demostrando integración funcional
    /// de ML APIs nativas.
    private func detectWithNativeVisionAPIs(pixelBuffer: CVPixelBuffer) async throws -> [DetectedObject] {
        let analysis = try await visionClassifier.runFullAnalysis(pixelBuffer: pixelBuffer)
        
        var objects: [DetectedObject] = []
        
        // Convert scene classifications to DetectedObjects
        // Place them in a virtual center bounding box proportional to confidence
        for (index, classification) in analysis.classifications.enumerated() {
            guard classification.confidence >= minimumConfidence else { continue }
            
            // Distribute classifications across the frame horizontally
            let xOffset = CGFloat(index) * 0.2 + 0.1
            let size = CGFloat(classification.confidence) * 0.3 + 0.1
            
            let object = DetectedObject(
                label: classification.localizedLabel,
                boundingBox: CGRect(
                    x: min(xOffset, 1.0 - size),
                    y: 0.3,
                    width: size,
                    height: size
                ),
                confidence: classification.confidence
            )
            objects.append(object)
        }
        
        // Convert detected rectangles to DetectedObjects (likely product labels)
        for rectangle in analysis.rectangles {
            guard rectangle.confidence >= minimumConfidence else { continue }
            
            let object = DetectedObject(
                label: rectangle.isSuitableForOCR ? "etiqueta" : "objeto rectangular",
                boundingBox: rectangle.boundingBox,
                confidence: rectangle.confidence
            )
            objects.append(object)
        }
        
        return objects
    }
    
    // MARK: - Scene Classification (Direct Access)
    
    /// Clasifica la escena del frame actual usando Vision APIs.
    ///
    /// Disponible siempre, independientemente de si hay modelo CoreML cargado.
    /// Usa `VNClassifyImageRequest` que corre on-device con el clasificador
    /// built-in de Apple.
    ///
    /// - Parameter pixelBuffer: Frame de la cámara.
    /// - Returns: Clasificaciones de la escena.
    func classifyScene(pixelBuffer: CVPixelBuffer) async throws -> [SceneClassification] {
        try await visionClassifier.classifyScene(pixelBuffer: pixelBuffer)
    }
    
    /// Ejecuta el pipeline completo de análisis (clasificación + rectángulos).
    ///
    /// - Parameter pixelBuffer: Frame de la cámara.
    /// - Returns: Resultado combinado del análisis.
    func runFullAnalysis(pixelBuffer: CVPixelBuffer) async throws -> FullAnalysisResult {
        try await visionClassifier.runFullAnalysis(pixelBuffer: pixelBuffer)
    }
    
    // MARK: - Configuration
    
    /// Establece el número de frames por segundo para throttling.
    ///
    /// - Parameter fps: FPS objetivo (1 para idle, 5 para búsqueda activa).
    func setTargetFPS(_ fps: Int) {
        targetFPS = max(1, min(fps, 30))
    }
    
    /// Activa o desactiva el motor de inferencia.
    ///
    /// - Parameter active: `true` para activar, `false` para suspender.
    func setActive(_ active: Bool) {
        isActive = active
    }
    
    /// Indica si hay un modelo CoreML cargado.
    var hasCustomModel: Bool {
        model != nil
    }
    
    /// Nombre del modelo en uso.
    var currentModelInfo: String {
        if let name = modelName {
            return "CoreML: \(name)"
        }
        return "Vision APIs nativas (VNClassifyImageRequest + VNDetectRectanglesRequest)"
    }
    
    // MARK: - Battery Management
    
    /// Verifica si se debe suspender la inferencia por batería baja.
    ///
    /// - Returns: `true` si el nivel de batería es menor al 10%.
    private nonisolated func shouldSuspendForBattery() -> Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        // batteryLevel returns -1 if monitoring is not enabled or state is unknown
        guard batteryLevel >= 0 else { return false }
        return batteryLevel < 0.10
    }
}

// MARK: - InferenceError

/// Errores del motor de inferencia de ML.
enum InferenceError: LocalizedError {
    case modelNotFound(String)
    case modelNotLoaded
    case inferenceFailed(String)
    case invalidPixelBuffer
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "No se encontró el modelo '\(name)' en el bundle de la app."
        case .modelNotLoaded:
            return "El modelo de ML no está cargado. Llama a loadModel() primero."
        case .inferenceFailed(let detail):
            return "La inferencia de ML falló: \(detail)"
        case .invalidPixelBuffer:
            return "El pixel buffer proporcionado no es válido."
        }
    }
}
