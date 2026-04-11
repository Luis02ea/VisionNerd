// MARK: - DietaryFilter.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - DietaryFilter

/// Filtros dietéticos extraídos de los comandos de voz del usuario.
///
/// Permite a GuideVision entender solicitudes como:
/// - "Buscar leche **sin gluten**"
/// - "Buscar pan **vegano**"
/// - "Buscar cereal **sin azúcar**"
///
/// ## Extracción
/// Se extraen usando coincidencia de keywords desde el texto reconocido
/// por el motor de voz.
public enum DietaryFilter: String, Sendable, Equatable, CaseIterable {
    
    /// Sin gluten.
    case glutenFree
    
    /// Sin lactosa.
    case lactoseFree
    
    /// Sin azúcar.
    case sugarFree
    
    /// Vegano.
    case vegan
    
    /// Vegetariano.
    case vegetarian
    
    /// Orgánico.
    case organic
    
    /// Bajo en sodio.
    case lowSodium
    
    /// Bajo en calorías.
    case lowCalorie
    
    // MARK: - Keywords
    
    /// Keywords para identificar este filtro en texto de voz.
    public var keywords: [String] {
        switch self {
        case .glutenFree:   return ["sin gluten", "libre de gluten", "gluten free"]
        case .lactoseFree:  return ["sin lactosa", "libre de lactosa", "deslactosado", "deslactosada"]
        case .sugarFree:    return ["sin azúcar", "sin azucar", "libre de azúcar", "sugar free", "sin endulzante"]
        case .vegan:        return ["vegano", "vegana", "vegan", "100% vegetal"]
        case .vegetarian:   return ["vegetariano", "vegetariana"]
        case .organic:      return ["orgánico", "orgánica", "organico", "organica", "bio"]
        case .lowSodium:    return ["bajo en sodio", "sin sal", "bajo sodio"]
        case .lowCalorie:   return ["bajo en calorías", "bajo en calorias", "light", "ligero", "ligera"]
        }
    }
    
    // MARK: - Localized Name
    
    /// Nombre localizado para mostrar al usuario.
    public var localizedName: String {
        switch self {
        case .glutenFree:   return "sin gluten"
        case .lactoseFree:  return "sin lactosa"
        case .sugarFree:    return "sin azúcar"
        case .vegan:        return "vegano"
        case .vegetarian:   return "vegetariano"
        case .organic:      return "orgánico"
        case .lowSodium:    return "bajo en sodio"
        case .lowCalorie:   return "bajo en calorías"
        }
    }
    
    // MARK: - Extraction
    
    /// Extrae filtros dietéticos de un texto de comando de voz.
    ///
    /// - Parameter text: Texto reconocido del comando de voz.
    /// - Returns: Array de filtros encontrados en el texto.
    public static func extract(from text: String) -> [DietaryFilter] {
        let lowercased = text.lowercased()
        return DietaryFilter.allCases.filter { filter in
            filter.keywords.contains { keyword in
                lowercased.contains(keyword)
            }
        }
    }
}
