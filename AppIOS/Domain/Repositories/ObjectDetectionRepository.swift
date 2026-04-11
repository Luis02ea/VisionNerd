//
//  ObjectDetectionRepository.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - ObjectDetectionRepository.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import CoreImage

// MARK: - ObjectDetectionRepository

/// Protocolo que define la interfaz para la detección de objetos en frames de cámara.
///
/// Implementado por ``ObjectDetectionRepositoryImpl`` en la capa Data,
/// que coordina ``CameraService`` con ``InferenceEngine``.
public protocol ObjectDetectionRepository: Sendable {
    
    /// Inicia el pipeline de detección de objetos.
    ///
    /// - Returns: Un stream asíncrono de arrays de objetos detectados.
    ///   Cada elemento del stream corresponde a un frame procesado.
    func startDetection() -> AsyncStream<[DetectedObject]>
    
    /// Detiene el pipeline de detección.
    func stopDetection() async
    
    /// Cambia la velocidad de procesamiento de frames.
    ///
    /// - Parameter fps: Frames por segundo objetivo (1 para idle, 5 para búsqueda activa).
    func setTargetFPS(_ fps: Int) async
    
    /// Busca un objeto específico en el frame actual.
    ///
    /// - Parameter query: Label del objeto a buscar.
    /// - Returns: Array de objetos que coinciden con la query, ordenados por confianza.
    func searchForObject(query: String) async -> [DetectedObject]
    
    /// Obtiene el objeto más cercano detectado actualmente.
    ///
    /// - Returns: El objeto con el bounding box más grande (más cercano), o `nil`.
    func getNearestObject() async -> DetectedObject?
}
