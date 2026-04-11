// MARK: - DetectObjectsUseCase.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - DetectObjectsUseCase

/// Caso de uso para la detección continua de objetos en tiempo real.
///
/// Coordina el repositorio de detección de objetos, controlando
/// la velocidad de procesamiento según el estado de la aplicación.
///
/// ## Uso típico
/// ```swift
/// let useCase = DetectObjectsUseCase(repository: objectDetectionRepo)
/// for await objects in useCase.execute(fps: 1) {
///     // Procesar objetos detectados
/// }
/// ```
public final class DetectObjectsUseCase: Sendable {
    
    private let repository: ObjectDetectionRepository
    
    /// Crea una nueva instancia del caso de uso.
    ///
    /// - Parameter repository: Repositorio de detección de objetos.
    public init(repository: ObjectDetectionRepository) {
        self.repository = repository
    }
    
    /// Ejecuta la detección continua de objetos.
    ///
    /// - Parameter fps: Frames por segundo objetivo.
    /// - Returns: Stream asíncrono de objetos detectados.
    public func execute(fps: Int = 1) -> AsyncStream<[DetectedObject]> {
        Task {
            await repository.setTargetFPS(fps)
        }
        return repository.startDetection()
    }
    
    /// Detiene la detección de objetos.
    public func stop() async {
        await repository.stopDetection()
    }
    
    /// Busca un objeto específico por nombre.
    ///
    /// - Parameter query: Nombre del objeto a buscar.
    /// - Returns: Objetos coincidentes ordenados por confianza.
    public func search(for query: String) async -> [DetectedObject] {
        await repository.searchForObject(query: query)
    }
    
    /// Obtiene el objeto más cercano.
    ///
    /// - Returns: El objeto detectado más cercano, o `nil`.
    public func nearestObject() async -> DetectedObject? {
        await repository.getNearestObject()
    }
}
