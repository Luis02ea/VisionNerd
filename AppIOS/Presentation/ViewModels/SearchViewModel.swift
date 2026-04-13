
import Foundation
import SwiftUI

typealias HorizontalDirection = DetectedObject.HorizontalDirection

@Observable
@MainActor
final class SearchViewModel {
    
    private(set) var state: SearchState = .idle
    
    private(set) var currentQuery: String = ""
    
    private(set) var targetObject: DetectedObject?
    
    private(set) var currentDirection: HorizontalDirection?
    
    private(set) var currentDistance: DistanceCategory?
    
    private(set) var proximityProgress: CGFloat = 0
    
    private(set) var elapsedTime: TimeInterval = 0
    
    private(set) var framesProcessed: Int = 0
    
    let announcementInterval: TimeInterval = 2.0
    
    private var lastAnnouncementTime: Date = .distantPast
    
    private var searchStartTime: Date?
    
    @discardableResult
    func transition(with event: SearchEvent) -> Bool {
        guard let newState = state.transition(with: event) else {
            return false
        }
        
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
    
    func updateDetectedObject(_ object: DetectedObject) -> String? {
        targetObject = object
        currentDirection = object.direction
        currentDistance = object.estimatedDistance
        proximityProgress = calculateProximity(boundingBox: object.boundingBox)
        framesProcessed += 1
        
        if let start = searchStartTime {
            elapsedTime = Date().timeIntervalSince(start)
        }
        
        let now = Date()
        guard now.timeIntervalSince(lastAnnouncementTime) >= announcementInterval else {
            return nil
        }
        
        lastAnnouncementTime = now
        return generateDirectionAnnouncement(for: object)
    }
    
    private func calculateProximity(boundingBox: CGRect) -> CGFloat {
        return min(1.0, boundingBox.height / 0.4)
    }
    
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
    
    var isSearchActive: Bool {
        switch state {
        case .scanning, .guiding:
            return true
        default:
            return false
        }
    }
}
