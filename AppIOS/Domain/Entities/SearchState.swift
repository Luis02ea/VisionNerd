//
//  SearchState.swift
//  AppIOS
//
//  Created by Alumno on 10/04/26.
//

import Foundation

public enum SerchState:  Sendable, Equatable
{
    case idle
    case listening
    case processing
    case scanning(query: String)
    case guiding(query:String, lastObject: DetectedObject?)
    case found (object: DetectedObject)
    case error (message: String)
    
//MARK Trancisiones, calcularemos el siguiente estado valido
    
    public func transition(with event: SearchEvent) -> SearchState?
    {
        switch (self, event)
        {
        case (.idle, .startListening):
            return .listening
        
        case (.listening, .textRecognized(let text)):
            return .processing
            
        case (.processing, .intentParsed(let query)):
            return .scanning(query: query)
            
        case (.scanning(let query), objectDetected(let object)):
            return .guiding(query: query, lastObject: object)
            
        
        }
    }
    
}
