// MARK: - InferenceEngine.swift
// GuideVision — Data Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import CoreML
import Vision
import UIKit


actor InferenceEngine {
    
 
    private var model: VNCoreMLModel?
    private var modelName: String?
    private let visionClassifier = VisionClassifierService()
    private(set) var isUsingNativeFallback: Bool = true
    private var targetFPS: Int = 1
    private var lastProcessingTime: Date = .distantPast
    private(set) var isActive: Bool = true
    private let minimumConfidence: Float = 0.65
    
    private let modelConfiguration: MLModelConfiguration = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return config
    }()
    
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
    

    func loadModel(from url: URL) throws {
        let mlModel = try MLModel(contentsOf: url, configuration: modelConfiguration)
        model = try VNCoreMLModel(for: mlModel)
        modelName = url.lastPathComponent
        isActive = true
        isUsingNativeFallback = false
        
        print("[InferenceEngine] ✅ CoreML model loaded from URL: \(url.lastPathComponent)")
    }
    
  
    func detectObjects(in pixelBuffer: CVPixelBuffer) async throws -> [DetectedObject] {
        guard !shouldSuspendForBattery() else {
            return []
        }
        
        let now = Date()
        let minInterval = 1.0 / Double(targetFPS)
        guard now.timeIntervalSince(lastProcessingTime) >= minInterval else {
            return []
        }
        
        lastProcessingTime = now
        
        if let model = model {
            return try await detectWithCoreML(model: model, pixelBuffer: pixelBuffer)
        } else {
            return try await detectWithNativeVisionAPIs(pixelBuffer: pixelBuffer)
        }
    }
    
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
    
 
    private func detectWithNativeVisionAPIs(pixelBuffer: CVPixelBuffer) async throws -> [DetectedObject] {
        let analysis = try await visionClassifier.runFullAnalysis(pixelBuffer: pixelBuffer)
        
        var objects: [DetectedObject] = []
        
        for (index, classification) in analysis.classifications.enumerated() {
            guard classification.confidence >= minimumConfidence else { continue }
            
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
    
    func classifyScene(pixelBuffer: CVPixelBuffer) async throws -> [SceneClassification] {
        try await visionClassifier.classifyScene(pixelBuffer: pixelBuffer)
    }
    
    func runFullAnalysis(pixelBuffer: CVPixelBuffer) async throws -> FullAnalysisResult {
        try await visionClassifier.runFullAnalysis(pixelBuffer: pixelBuffer)
    }
    
    func setTargetFPS(_ fps: Int) {
        targetFPS = max(1, min(fps, 30))
    }
    
    func setActive(_ active: Bool) {
        isActive = active
    }
    
    var hasCustomModel: Bool {
        model != nil
    }
    
    var currentModelInfo: String {
        if let name = modelName {
            return "CoreML: \(name)"
        }
        return "Vision APIs nativas (VNClassifyImageRequest + VNDetectRectanglesRequest)"
    }
    
  
    private nonisolated func shouldSuspendForBattery() -> Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        guard batteryLevel >= 0 else { return false }
        return batteryLevel < 0.10
    }
}

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
