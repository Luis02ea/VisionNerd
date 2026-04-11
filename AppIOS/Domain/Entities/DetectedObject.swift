//
//  DetectedObject.swift
//  AppIOS
//
//  Created by Alumno on 10/04/26.
//

import Foundation
import CoreGraphics

public struct DetectedObject: Identifiable, Sendable, Equatable
{
    public let id: UUID
    public let label: String
    public let boundingBox: CGRect
    public let confidence: Float
    public let estimatedDistance: DistanceCategory
    public let timestamp: Date
    
    public init(id: UUID, label: String, boundingBox: CGRect, confidence: Float, estimatedDistance: DistanceCategory, timestamp: Date) {
        self.id = id
        self.label = label
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.estimatedDistance = estimatedDistance
        self.timestamp = timestamp
    }
    public var horizontalPosition: CGFloat
    {
        boundingBox.midX
    }
    public var verticalPosition: CGFloat
    {
        boundingBox.midY
    }
    public var direction: HorizontalDirection
    {
        HorizontalDirection.from(normalizedX: horizontalPosition)
    }
    
    public var spokenDescription: String
    {
        let directionText: String
        switch direction{
        case .left:
            directionText = "a tu izquierda"
        case .center:
            directionText = "Justo enfrente"
        case .right:
            directionText = "a tu derecha"
        }
        return "\(label) \(direction), \(estimatedDistance.shortDescription)"
    }
//MARK: A qui defini si el objeto esta suficientemente cerca para considerarlo como encontrado
    
    public var isVeryClose: Bool
    {
        boundingBox.height > 0.4
    }
    
    public static func == (lhs: DetectedObject, rhs: DetectedObject) -> Bool
    {
        lhs.id == rhs.id
    }
// MARK: aqui defini la confianza minima requerida para aceptar una detencion
    extension DetectedObject
    {
        public static let minimumConfidence: Float = 0.5
    }
    
//MARK: Aqui definimos con respecto del objecto detectado horzontalmente conforme al centro del frame
    
    public enum HorizontalDirection: String, Sendable
    {
        case left
        case center
        case right
        
        
        public static func from(normalizedX: CGFloat) -> HorizontalDirection
        {
            switch normalizedX
            {
            case 0.0..<0.35:
                return .left
            case 0.35..<0.65:
                return .center
            default:
                return .right
            }
        }
        public var azimuthDegrees: CGFloat
        {
            switch self
            {
                case .left:
                    return -90.0
                case .center:
                    return 0.0
                case .right:
                    return 90.0
            }
        }
        
        public var localizedDescription: String
        {
            switch self
            {
                case .left:
                    return "a la izquierda"
                case .center:
                    return "en el centro"
                case .right:
                    return "a la derecha"
            }
        }
        
    }
    
}
