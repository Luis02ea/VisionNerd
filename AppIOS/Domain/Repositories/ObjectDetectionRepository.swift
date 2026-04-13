//
//  ObjectDetectionRepository.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//


import Foundation
import CoreImage

// MARK: - ObjectDetectionRepository

/// Protocolo que define la interfaz para la detección de objetos en frames de cámara.
///
/// Implementado por ``ObjectDetectionRepositoryImpl`` en la capa Data,
/// que coordina ``CameraService`` con ``InferenceEngine``.
public protocol ObjectDetectionRepository: Sendable {
    
   
    func startDetection() -> AsyncStream<[DetectedObject]>
    
    func stopDetection() async
    
    /// - Parameter fps: Frames por segundo objetivo (1 para idle, 5 para búsqueda activa).
    func setTargetFPS(_ fps: Int) async
    

    func searchForObject(query: String) async -> [DetectedObject]
    

    func getNearestObject() async -> DetectedObject?
}
