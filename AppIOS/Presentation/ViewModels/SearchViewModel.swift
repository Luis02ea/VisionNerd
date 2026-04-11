// MARK: - SearchViewModel.swift
// GuideVision — Presentation Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import SwiftUI

// MARK: - Type Aliases

/// Alias for the nested HorizontalDirection type.
private typealias HorizontalDirection = DetectedObject.HorizontalDirection

// MARK: - SearchViewModel

/// ViewModel dedicado para el flujo de búsqueda guiada.
///
/// Gestiona la máquina de estados de búsqueda con transiciones explícitas,
/// actualizaciones de dirección espacial, y coordinación de feedback
/// audio-háptico.
///
/// Esta clase complementa a ``MainViewModel`` para encapsular
/// la lógica de búsqueda en un componente reutilizable.
@Observable
@MainActor
final class SearchViewModel {
    
    // MARK: - State
    
    /// Estado actual de la búsqueda.
    private(set) var state: SearchState = .idle
    
    /// Query de búsqueda actual.
    private(set) var currentQuery: String = ""
    
    /// Último objeto detectado que coincide con la búsqueda.
    private(set) var targetObject: DetectedObject?
    
    /// Dirección actual del objeto buscado.
    private(set) var currentDirection: HorizontalDirection?
    
    /// Distancia actual del objeto buscado.
    private(set) var currentDistance: DistanceCategory?
    
    /// Porcentaje de proximidad (0.0 = lejos, 1.0 = llegó).
    private(set) var proximityProgress: CGFloat = 0
    
    /// Tiempo transcurrido desde el inicio de la búsqueda.
    private(set) var elapsedTime: TimeInterval = 0
    
    /// Contador de frames procesados.
    private(set) var framesProcessed: Int = 0
    
    // MARK: - Configuration
    
    /// Intervalo mínimo entre anuncios de dirección (segundos).
    let announcementInterval: TimeInterval = 2.0
    
    /// Timestamp del último anuncio.
    private var lastAnnouncementTime: Date = .distantPast
    
    /// Timestamp de inicio de la búsqueda.
    private var searchStartTime: Date?
    
    // MARK: - State Machine
    
    /// Transiciona al siguiente estado dado un evento.
    ///
    /// - Parameter event: El evento que dispara la transición.
    /// - Returns: `true` si la transición fue válida.
    @discardableResult
    func transition(with event: SearchEvent) -> Bool {
        guard let newState = state.transition(with: event) else {
            return false
        }
        
        // Handle state-specific logic
        switch newState {
        case .scanning(let query):
            currentQuery = query
            searchStartTime = Date()
            
        case .guiding(_, let object):
            if let obj = object {
                targetObject = obj
                currentDirection = obj.direction
                currentDistance = obj.estimatedDistance
                proximityProgress = calculateProximity(boundingBox: obj.boundingBox)
            }
            
        case .found(let object):
            targetObject = object
            proximityProgress = 1.0
            
        case .idle:
            resetSearch()
            
        default:
            break
        }
        
        state = newState
        return true
    }
    
    // MARK: - Object Update
    
    /// Actualiza la información del objeto detectado durante la guía.
    ///
    /// - Parameter object: El objeto detectado actualizado.
    /// - Returns: Texto de anuncio si han pasado suficientes segundos, o `nil`.
    func updateDetectedObject(_ object: DetectedObject) -> String? {
        targetObject = object
        currentDirection = object.direction
        currentDistance = object.estimatedDistance
        proximityProgress = calculateProximity(boundingBox: object.boundingBox)
        framesProcessed += 1
        
        if let start = searchStartTime {
            elapsedTime = Date().timeIntervalSince(start)
        }
        
        // Check if enough time has passed for an announcement
        let now = Date()
        guard now.timeIntervalSince(lastAnnouncementTime) >= announcementInterval else {
            return nil
        }
        
        lastAnnouncementTime = now
        return generateDirectionAnnouncement(for: object)
    }
    
    // MARK: - Proximity Calculation
    
    /// Calcula el progreso de proximidad basado en el bounding box.
    ///
    /// - Parameter boundingBox: Bounding box normalizado del objeto.
    /// - Returns: Progreso de 0.0 (lejos) a 1.0 (encontrado).
    private func calculateProximity(boundingBox: CGRect) -> CGFloat {
        // 0.0 → 0%, 0.4 (isVeryClose threshold) → 100%
        return min(1.0, boundingBox.height / 0.4)
    }
    
    // MARK: - Announcement Generation
    
    /// Genera un anuncio de dirección para el usuario.
    private func generateDirectionAnnouncement(for object: DetectedObject) -> String {
        let direction: String
        switch object.direction {
        case .left:
            direction = "Está a tu izquierda"
        case .center:
            direction = "Está justo enfrente"
        case .right:
            direction = "Está a tu derecha"
        }
        
        return "\(direction), \(object.estimatedDistance.shortDescription)"
    }
    
    // MARK: - Reset
    
    /// Resetea todo el estado de búsqueda.
    private func resetSearch() {
        currentQuery = ""
        targetObject = nil
        currentDirection = nil
        currentDistance = nil
        proximityProgress = 0
        elapsedTime = 0
        framesProcessed = 0
        searchStartTime = nil
        lastAnnouncementTime = .distantPast
    }
    
    // MARK: - Computed Properties
    
    /// Texto descriptivo del estado actual.
    var statusText: String {
        switch state {
        case .idle:
            return "Listo para buscar"
        case .listening:
            return "Escuchando..."
        case .processing:
            return "Procesando..."
        case .scanning(let query):
            return "Buscando: \(query)"
        case .guiding(let query, _):
            if let dir = currentDirection, let dist = currentDistance {
                return "\(query) — \(dir.localizedDescription), \(dist.shortDescription)"
            }
            return "Guiando hacia \(query)"
        case .found(let object):
            return "¡Encontrado! \(object.label)"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
    
    /// Indica si hay una búsqueda activa.
    var isSearchActive: Bool {
        switch state {
        case .scanning, .guiding:
            return true
        default:
            return false
        }
    }
}
