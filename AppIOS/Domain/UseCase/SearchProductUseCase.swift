// MARK: - SearchProductUseCase.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - SearchProductUseCase

/// Caso de uso para el flujo completo de búsqueda guiada de productos.
///
/// Orquesta el pipeline desde la activación de búsqueda hasta
/// guiar al usuario al producto usando audio espacial y feedback háptico.
public final class SearchProductUseCase: Sendable {
    
    private let detectionRepository: ObjectDetectionRepository
    
    /// Crea una nueva instancia del caso de uso.
    ///
    /// - Parameter detectionRepository: Repositorio de detección de objetos.
    public init(detectionRepository: ObjectDetectionRepository) {
        self.detectionRepository = detectionRepository
    }
    
    /// Inicia la búsqueda activa de un producto.
    ///
    /// Configura el pipeline a 5fps y devuelve un stream de detecciones
    /// filtradas por la query del usuario.
    ///
    /// - Parameter query: Nombre del producto a buscar.
    /// - Returns: Stream de objetos detectados que coinciden con la query.
    public func startSearch(query: String) -> AsyncStream<[DetectedObject]> {
        Task {
            await detectionRepository.setTargetFPS(5)
        }
        return detectionRepository.startDetection()
    }
    
    /// Filtra detecciones para encontrar objetos que coincidan con la query.
    ///
    /// - Parameters:
    ///   - objects: Objetos detectados en el frame actual.
    ///   - query: Nombre del producto buscado.
    /// - Returns: Objetos que coinciden con la query.
    public func filterResults(_ objects: [DetectedObject], for query: String) -> [DetectedObject] {
        let lowercasedQuery = query.lowercased()
        return objects.filter { object in
            object.label.lowercased().contains(lowercasedQuery) ||
            lowercasedQuery.contains(object.label.lowercased())
        }
    }
    
    /// Detiene la búsqueda y vuelve a modo idle (1fps).
    public func stopSearch() async {
        await detectionRepository.setTargetFPS(1)
    }
}
