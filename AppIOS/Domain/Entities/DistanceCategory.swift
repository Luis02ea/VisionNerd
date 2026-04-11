//
//  DistanceCategory.swift
//  AppIOS
//
//  Created by Alumno on 10/04/26.
//

import Foundation
import CoreGraphics

public enum DistanceCategory: String, Sendable, Codable, CaseIterable
{
    case near
    case medium
    case far
    
    static let nearThreshold: CGFloat = 0.35
    static let mediumThreshold: CGFloat = 0.15
    
    public static func estimate(from boundingBox: CGRect) -> DistanceCategory
    {
        let relativeSize = max(boundingBox.width, boundingBox.height)
        
        if relativeSize > nearThreshold
        {
            return .near
        }
        else if relativeSize > mediumThreshold
        {
            return .medium
        }
        else
        {
            return .far
        }
    }
    
    public var shortDescription: String {
        switch self {
        case .near: return "muy cerca"
        case .medium: return "a distancia media"
        case .far: return "lejos"
        }
    }
    
    /// Descripción localizada para anuncios de accesibilidad.
    public var localizedDescription: String {
        switch self {
        case .near: return "muy cerca"
        case .medium: return "a distancia media"
        case .far: return "lejos"
        }
    }
    
    /// Ganancia de audio para el SpatialAudioEngine (0.0–1.0).
    public var audioGain: Double {
        switch self {
        case .near:   return 1.0
        case .medium: return 0.65
        case .far:    return 0.3
        }
    }
    
    /// Multiplicador de pitch para el SpatialAudioEngine.
    public var audioPitch: Double {
        switch self {
        case .near:   return 1.05
        case .medium: return 1.0
        case .far:    return 0.95
        }
    }
}

