//
//  CreateMLTrainer.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - CreateMLTrainer.swift
// GuideVision — Data Layer / ML Training
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

#if canImport(CreateML)
import CreateML
import CoreML

// MARK: - CreateMLTrainer

/// Utilidad para entrenar clasificadores personalizados usando Create ML.
///
/// Demuestra integración funcional de **Create ML** para generar
/// modelos .mlmodel directamente desde la app o en un playground.
///
/// ## Flujo de entrenamiento
/// 1. Organizar imágenes en carpetas por categoría
/// 2. Llamar a `trainImageClassifier()` con la ruta del dataset
/// 3. El modelo se guarda como .mlmodel y se puede cargar en `InferenceEngine`
///
/// ## Estructura del dataset requerida
/// ```
/// TrainingData/
/// ├── leche/
/// │   ├── img_001.jpg
/// │   └── img_002.jpg
/// ├── pan/
/// │   ├── img_001.jpg
/// │   └── img_002.jpg
/// └── agua/
///     ├── img_001.jpg
///     └── img_002.jpg
/// ```
///
/// ## Integración con la app
/// Una vez entrenado, el modelo se puede:
/// - Agregar al bundle de Xcode como .mlpackage
/// - Descargar on-demand vía `MLModelCollection`
/// - Cargar dinámicamente con `InferenceEngine.loadModel(from:)`
@available(iOS 17.0, macOS 14.0, *)
final class CreateMLTrainer {
    
    // MARK: - Image Classifier Training
    
    /// Entrena un clasificador de imágenes con Transfer Learning.
    ///
    /// Usa `MLImageClassifier` de Create ML que aplica transfer learning
    /// sobre un modelo base preentrenado de Apple, requiriendo pocas imágenes
    /// por categoría (mínimo ~10).
    ///
    /// - Parameters:
    ///   - trainingDataURL: URL de la carpeta con imágenes organizadas por clase.
    ///   - validationDataURL: URL opcional de datos de validación.
    ///   - outputURL: URL donde guardar el modelo entrenado.
    ///   - modelName: Nombre del modelo de salida.
    ///   - maxIterations: Número máximo de iteraciones de entrenamiento.
    /// - Returns: Métricas de evaluación del modelo entrenado.
    /// - Throws: Error si el entrenamiento falla.
    static func trainImageClassifier(
        trainingDataURL: URL,
        validationDataURL: URL? = nil,
        outputURL: URL,
        modelName: String = "GuideVisionClassifier",
        maxIterations: Int = 25
    ) throws -> TrainingMetrics {
        
        // Step 1: Load training data from directory structure
        let trainingData = try MLImageClassifier.DataSource.labeledDirectories(at: trainingDataURL)
        
        // Step 2: Configure training parameters
        let parameters = MLImageClassifier.ModelParameters(
            maxIterations: maxIterations,
            augmentation: [
                .crop,
                .rotation(range: -15...15),
                .blur(radius: 0.5...2.0),
                .exposure(range: -1.0...1.0),
                .noise(variance: 0.01...0.05),
                .flip(horizontal: true)
            ]
        )
        
        // Step 3: Train the model with Create ML
        let classifier = try MLImageClassifier(
            trainingData: trainingData,
            parameters: parameters
        )
        
        // Step 4: Evaluate on training data
        let trainingAccuracy = (try? classifier.evaluation(on: trainingData))
        let trainingError = trainingAccuracy?.classificationError ?? 1.0
        
        // Step 5: Evaluate on validation data if provided
        var validationError: Double = -1
        if let validationURL = validationDataURL {
            let validationData = try MLImageClassifier.DataSource.labeledDirectories(at: validationURL)
            let valEval = try? classifier.evaluation(on: validationData)
            validationError = valEval?.classificationError ?? -1
        }
        
        // Step 6: Save the model with metadata
        let metadata = MLModelMetadata(
            author: "GuideVision Create ML Trainer",
            shortDescription: "Clasificador de productos para personas con discapacidad visual. Entrenado con Create ML Transfer Learning.",
            license: "Propietario",
            version: "1.0",
            additional: [
                "task": "image_classification",
                "training_iterations": "\(maxIterations)",
                "framework": "Create ML"
            ]
        )
        
        let modelURL = outputURL.appendingPathComponent("\(modelName).mlmodel")
        try classifier.write(to: modelURL, metadata: metadata)
        
        print("[CreateML] ✅ Modelo guardado en: \(modelURL.path)")
        print("[CreateML] Training error: \(trainingError)")
        if validationError >= 0 {
            print("[CreateML] Validation error: \(validationError)")
        }
        
        return TrainingMetrics(
            modelURL: modelURL,
            trainingError: trainingError,
            validationError: validationError >= 0 ? validationError : nil,
            iterations: maxIterations
        )
    }
    
    // MARK: - Model Compilation
    
    /// Compila un modelo .mlmodel a .mlmodelc para uso en producción.
    ///
    /// La compilación optimiza el modelo para el hardware específico
    /// (Neural Engine, GPU, CPU) del dispositivo objetivo.
    ///
    /// - Parameter modelURL: URL del archivo .mlmodel.
    /// - Returns: URL del modelo compilado .mlmodelc.
    /// - Throws: Error si la compilación falla.
    static func compileModel(at modelURL: URL) throws -> URL {
        let compiledURL = try MLModel.compileModel(at: modelURL)
        print("[CreateML] ✅ Modelo compilado en: \(compiledURL.path)")
        return compiledURL
    }
    
    // MARK: - Live Model Loading
    
    /// Entrena y carga un modelo directamente en el InferenceEngine.
    ///
    /// Flujo completo: entrenar → compilar → cargar en el motor de inferencia.
    ///
    /// - Parameters:
    ///   - trainingDataURL: URL de los datos de entrenamiento.
    ///   - engine: Motor de inferencia donde cargar el modelo.
    ///   - outputURL: URL temporal para guardar el modelo.
    /// - Returns: Métricas del entrenamiento.
    static func trainAndLoad(
        trainingDataURL: URL,
        into engine: InferenceEngine,
        outputURL: URL
    ) async throws -> TrainingMetrics {
        // Train
        let metrics = try trainImageClassifier(
            trainingDataURL: trainingDataURL,
            outputURL: outputURL,
            modelName: "GuideVisionCustom"
        )
        
        // Compile
        let compiledURL = try compileModel(at: metrics.modelURL)
        
        // Load into engine
        try await engine.loadModel(from: compiledURL)
        
        print("[CreateML] ✅ Modelo personalizado cargado en InferenceEngine")
        
        return metrics
    }
}

// MARK: - TrainingMetrics

/// Métricas resultantes del entrenamiento con Create ML.
struct TrainingMetrics {
    /// URL del modelo entrenado.
    let modelURL: URL
    
    /// Error de clasificación en datos de entrenamiento (0.0 = perfecto).
    let trainingError: Double
    
    /// Error de clasificación en datos de validación (nil si no hay validación).
    let validationError: Double?
    
    /// Número de iteraciones completadas.
    let iterations: Int
    
    /// Precisión de entrenamiento (1.0 - error).
    var trainingAccuracy: Double {
        1.0 - trainingError
    }
    
    /// Precisión de validación (1.0 - error), si hay datos de validación.
    var validationAccuracy: Double? {
        guard let error = validationError else { return nil }
        return 1.0 - error
    }
}

#else

// MARK: - Stub for non-macOS platforms

/// Stub cuando Create ML no está disponible (requiere macOS o Catalyst).
///
/// Create ML framework solo está disponible en macOS y Mac Catalyst.
/// En iOS puro, los modelos se entrenan externamente y se importan
/// como .mlpackage o .mlmodelc.
///
/// Para entrenar modelos:
/// 1. Usa un playground de Swift en Xcode (macOS)
/// 2. Usa Create ML App (macOS)
/// 3. Usa el script Python con coremltools
///
/// ## Ejemplo de entrenamiento en Xcode Playground
/// ```swift
/// import CreateML
///
/// let trainingData = try MLImageClassifier.DataSource
///     .labeledDirectories(at: URL(fileURLWithPath: "/path/to/data"))
///
/// let classifier = try MLImageClassifier(trainingData: trainingData)
/// try classifier.write(to: URL(fileURLWithPath: "/path/to/output/model.mlmodel"))
/// ```
struct CreateMLTrainer {
    static func trainImageClassifier(
        trainingDataURL: URL,
        outputURL: URL
    ) throws -> TrainingMetrics {
        fatalError("Create ML no está disponible en esta plataforma. Use macOS para entrenar modelos.")
    }
}

struct TrainingMetrics {
    let modelURL: URL
    let trainingError: Double
    let validationError: Double?
    let iterations: Int
}

#endif
