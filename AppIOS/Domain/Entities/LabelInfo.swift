// MARK: - LabelInfo.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - LabelInfo

/// Información estructurada de una etiqueta de producto leída por OCR.
///
/// Contiene la información extraída y parseada del texto reconocido
/// en una etiqueta de producto, incluyendo nombre, ingredientes,
/// información nutricional y fecha de vencimiento.
///
/// ## Uso
/// ```swift
/// let label = try await ocrRepository.readCurrentFrame()
/// speechSynthesizer.speak(label.spokenSummary)
/// ```
public struct LabelInfo: Sendable, Equatable {
    
    /// Nombre del producto extraído de la etiqueta.
    public let productName: String?
    
    /// Lista de ingredientes extraídos.
    public let ingredients: [String]
    
    /// Información nutricional parseada.
    public let nutritionInfo: NutritionInfo?
    
    /// Fecha de vencimiento encontrada en la etiqueta.
    public let expirationDate: String?
    
    /// Texto crudo reconocido por OCR.
    public let rawText: String
    
    // MARK: - Initialization
    
    public init(
        productName: String?,
        ingredients: [String],
        nutritionInfo: NutritionInfo?,
        expirationDate: String?,
        rawText: String
    ) {
        self.productName = productName
        self.ingredients = ingredients
        self.nutritionInfo = nutritionInfo
        self.expirationDate = expirationDate
        self.rawText = rawText
    }
    
    // MARK: - Spoken Summary
    
    /// Genera un resumen hablado de la etiqueta para síntesis de voz.
    ///
    /// Incluye nombre del producto, ingredientes principales,
    /// información nutricional y fecha de vencimiento si están disponibles.
    public var spokenSummary: String {
        var parts: [String] = []
        
        if let name = productName, !name.isEmpty {
            parts.append("Producto: \(name)")
        }
        
        if !ingredients.isEmpty {
            let ingredientList = ingredients.prefix(5).joined(separator: ", ")
            parts.append("Ingredientes principales: \(ingredientList)")
        }
        
        if let nutrition = nutritionInfo {
            parts.append(nutrition.spokenSummary)
        }
        
        if let expDate = expirationDate {
            parts.append("Fecha de vencimiento: \(expDate)")
        }
        
        if parts.isEmpty {
            if rawText.isEmpty {
                return "No pude leer texto en la etiqueta. Asegúrate de que esté bien enfocada."
            } else {
                return "Texto leído: \(rawText.prefix(200))"
            }
        }
        
        return parts.joined(separator: ". ") + "."
    }
}
