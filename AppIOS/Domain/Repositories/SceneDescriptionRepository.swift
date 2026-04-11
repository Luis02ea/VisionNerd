// MARK: - SceneDescriptionRepository.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - SceneDescriptionRepository

/// Protocolo que define la interfaz para la descripción de escenas.
///
/// Combina detección de objetos local (Core ML) con IA en la nube
/// (OpenAI Vision API o Claude claude-sonnet-4-20250514) para generar descripciones
/// detalladas de la escena capturada por la cámara.
public protocol SceneDescriptionRepository: Sendable {
    
    /// Genera una descripción de la escena actual.
    ///
    /// Primero intenta con detección local (Core ML). Si los resultados
    /// son insuficientes, recurre a la API en la nube como fallback.
    ///
    /// - Returns: Descripción textual de la escena para síntesis de voz.
    /// - Throws: Error si ambos métodos fallan.
    func describeCurrentScene() async throws -> String
    
    /// Genera una descripción usando solo detección local.
    ///
    /// - Parameter objects: Objetos detectados en el frame actual.
    /// - Returns: Descripción textual basada en objetos locales.
    func describeLocally(objects: [DetectedObject]) -> String
    
    /// Genera una descripción usando la API en la nube.
    ///
    /// - Parameter imageData: Datos de la imagen en formato JPEG.
    /// - Returns: Descripción generada por el modelo de IA.
    /// - Throws: Error de red o de la API.
    func describeWithCloudAI(imageData: Data) async throws -> String
}
