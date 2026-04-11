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
    
    
}

