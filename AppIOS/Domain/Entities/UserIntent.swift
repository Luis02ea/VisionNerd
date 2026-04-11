// MARK: - UserIntent.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - UserIntent

/// Representa la intención del usuario parseada desde un comando de voz.
///
/// El ``NLUParser`` transforma texto reconocido por el motor de voz
/// en una de estas intenciones, que luego controla el flujo de la aplicación.
///
/// ## Intenciones soportadas
/// - `.search(query:, filters:)` — Buscar un producto específico
/// - `.describeScene` — Describir lo que la cámara está viendo
/// - `.readLabel` — Leer la etiqueta/texto frente a la cámara (OCR)
/// - `.getDistance` — Consultar la distancia al objeto más cercano
/// - `.cancel` — Cancelar la operación actual
/// - `.unknown` — Intención no reconocida
public enum UserIntent: Sendable, Equatable {
    
    /// Buscar un producto específico con filtros dietéticos opcionales.
    ///
    /// - Parameters:
    ///   - query: Nombre del producto a buscar (e.g., "leche", "pan integral").
    ///   - filters: Filtros dietéticos extraídos del comando (e.g., "sin gluten").
    case search(query: String, filters: [DietaryFilter])
    
    /// Describir la escena actual capturada por la cámara.
    case describeScene
    
    /// Activar OCR para leer texto/etiquetas frente a la cámara.
    case readLabel
    
    /// Consultar la distancia al objeto detectado más cercano.
    case getDistance
    
    /// Cancelar la operación en curso.
    case cancel
    
    /// Intención no reconocida — se pide al usuario que repita.
    case unknown(rawText: String)
    
    // MARK: - Properties
    
    /// Descripción verbal de la intención para feedback al usuario.
    public var confirmationMessage: String {
        switch self {
        case .search(let query, let filters):
            var message = "Buscando \(query)"
            if !filters.isEmpty {
                let filterNames = filters.map(\.localizedName).joined(separator: ", ")
                message += " con filtros: \(filterNames)"
            }
            return message
        case .describeScene:
            return "Describiendo la escena"
        case .readLabel:
            return "Leyendo etiqueta"
        case .getDistance:
            return "Calculando distancia"
        case .cancel:
            return "Cancelando"
        case .unknown(let rawText):
            return "No entendí: \(rawText). Por favor, repite tu solicitud."
        }
    }
}
