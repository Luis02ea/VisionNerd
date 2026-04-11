// MARK: - GuideDirection.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - GuideDirection

/// Dirección de guía para indicar al usuario hacia dónde moverse.
///
/// Generada durante el estado `.guiding` para proporcionar
/// instrucciones de dirección con audio espacial y texto.
///
/// ## Uso
/// ```swift
/// let direction = GuideDirection(
///     side: .right,
///     instruction: "Gira ligeramente a la derecha",
///     detail: "Cereal · ~1.8m · confianza 94%"
/// )
/// ```
public struct GuideDirection: Sendable, Equatable {
    
    /// Lado hacia el cual dirigirse.
    public let side: Side
    
    /// Instrucción verbal para el usuario.
    public let instruction: String
    
    /// Detalle adicional (producto, distancia, confianza).
    public let detail: String
    
    // MARK: - Initialization
    
    public init(side: Side, instruction: String, detail: String) {
        self.side = side
        self.instruction = instruction
        self.detail = detail
    }
    
    // MARK: - Side Enum
    
    /// Dirección lateral del objeto detectado.
    public enum Side: String, Sendable, Equatable {
        case left
        case center
        case right
    }
    
    // MARK: - Factory
    
    /// Crea una GuideDirection a partir de un DetectedObject.
    ///
    /// - Parameter object: El objeto detectado que determina la dirección.
    /// - Returns: Dirección de guía con instrucciones apropiadas.
    public static func from(object: DetectedObject) -> GuideDirection {
        let side: Side
        let instruction: String
        
        switch object.direction {
        case .left:
            side = .left
            instruction = "Gira hacia la izquierda"
        case .center:
            side = .center
            instruction = "Sigue recto, está enfrente"
        case .right:
            side = .right
            instruction = "Gira hacia la derecha"
        }
        
        let detail = "\(object.label) · \(object.estimatedDistance.shortDescription) · confianza \(Int(object.confidence * 100))%"
        
        return GuideDirection(side: side, instruction: instruction, detail: detail)
    }
}
