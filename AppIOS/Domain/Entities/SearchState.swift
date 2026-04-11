//
//  SearchState.swift
//  AppIOS
//
//  Created by Alumno on 10/04/26.
//

import Foundation
import CoreGraphics

public enum SearchState: Sendable, Equatable
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
            
        case (.scanning(let query), .objectDetected(let object)):
            return .guiding(query: query, lastObject: object)
            
        case (.guiding(let query, _), .objectDetected(let object)):
            return .guiding(query: query, lastObject: object)
            
        case (.guiding(_,_), .objectReached(let object)):
            return .found(object: object)
            
        case (.found, .reset):
            return .idle
            
        case (.scanning(let query), .noObjectFound):
            return .scanning(query: query)
            
        case (_, .cancel):
            return .idle
        
        case (_, .errorOccurred(let message)):
            return .error(message: message)
        
        case (.error, .reset):
            return .idle
            
        default:
            return nil
        }
    }
    
    public var requieresActiveCamera: Bool
    {
        switch self
        {
        case .scanning, .guiding:
            return true
        
        default:
            return false
        }
    }
    public var targetFPS: Int
    {
        switch self
        {
            case .scanning, .guiding:
                return 5
            case .idle:
                return 1
            default:
                return 0
        }
    }
    
    public var requieresSpatialAudio: Bool
    {
        switch self
        {
            case .guiding:
                return true
            default:
                return false
        }
    }
    
    public var entryAnnouncement: String?
    {
        switch self
        {
            case .idle:
                return nil
            case .listening:
                return "Escuchando. Dime que buscas."
            case .processing:
                return "Procesando la solicitud."
            case .scanning(let query):
                return "Buscando \(query). Mueve la camara lentamente."
            case .guiding(let query, _):
                return "Guiandote hacia \(query)."
            case .found(let object):
                return "¡Llegaste! \(object.label) está aquí justo enfrente a ti."
            case .error(let message):
                return "Error: \(message)"
            
        }
    }
    
    public var name: String
    {
        switch self
        {
            case .idle:
                return "Inactivo"
            case .listening:
                return "Escuchando"
            case .processing:
                return "Procesando"
            case .scanning:
                return "Buscando"
            case .guiding:
                return "Guiado"
            case .found:
                return "Encontrado"
            case .error:
                return "Error"
        }
    }
//MARK Aqui puse los eventos que se disparan al momento de transiciones en la maquina de estados de busqueda.
    
    public enum SearchEvent: Sendable
    {
        case startListening
        case textRecognized(String)
        case intentParsed(query: String)
        case objectDetected(DetectedObject)
        case noObjectFound
        case objectReached(DetectedObject)
        case cancel
        case errorOccurred(String)
        case reset
        
    }
}

// MARK: - Top-Level Type Alias

/// Alias para acceder a SearchEvent sin calificar con SearchState.
public typealias SearchEvent = SearchState.SearchEvent
