// MARK: - NutritionInfo.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - NutritionInfo

/// Información nutricional extraída de una etiqueta de producto.
///
/// Almacena los valores nutricionales parseados del texto OCR
/// como strings, ya que los formatos varían entre etiquetas
/// (e.g., "120 kcal", "5g", "12%").
public struct NutritionInfo: Sendable, Equatable {
    
    /// Calorías (e.g., "120 kcal").
    public let calories: String?
    
    /// Grasa total (e.g., "5g").
    public let totalFat: String?
    
    /// Carbohidratos (e.g., "22g").
    public let carbohydrates: String?
    
    /// Proteína (e.g., "8g").
    public let protein: String?
    
    /// Azúcar (e.g., "12g").
    public let sugar: String?
    
    // MARK: - Initialization
    
    public init(
        calories: String? = nil,
        totalFat: String? = nil,
        carbohydrates: String? = nil,
        protein: String? = nil,
        sugar: String? = nil
    ) {
        self.calories = calories
        self.totalFat = totalFat
        self.carbohydrates = carbohydrates
        self.protein = protein
        self.sugar = sugar
    }
    
    // MARK: - Spoken Summary
    
    /// Genera un resumen hablado de la información nutricional.
    public var spokenSummary: String {
        var parts: [String] = []
        
        if let cal = calories {
            parts.append("Calorías: \(cal)")
        }
        if let fat = totalFat {
            parts.append("Grasa: \(fat)")
        }
        if let carbs = carbohydrates {
            parts.append("Carbohidratos: \(carbs)")
        }
        if let prot = protein {
            parts.append("Proteína: \(prot)")
        }
        if let sug = sugar {
            parts.append("Azúcar: \(sug)")
        }
        
        if parts.isEmpty {
            return "Sin información nutricional disponible"
        }
        
        return "Información nutricional: " + parts.joined(separator: ", ")
    }
}
