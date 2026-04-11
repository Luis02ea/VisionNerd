// MARK: - OCRCache.swift


import Foundation

// MARK: - OCRCache

/// Cache de resultados OCR usando `NSCache`.
///
/// Almacena texto reconocido indexado por el hash del frame de la cámara
/// para evitar re-procesar frames similares.
///
/// ## Configuración
/// - Límite de 50 entradas
/// - Límite de 5 MB de memoria
/// - Eviction automática por presión de memoria
final class OCRCache: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Cache subyacente NSCache.
    private let cache: NSCache<NSString, CacheEntry>
    
    // MARK: - Initialization
    
    /// Crea una nueva instancia del cache OCR.
    ///
    /// - Parameters:
    ///   - countLimit: Número máximo de entradas (default: 50).
    ///   - totalCostLimit: Límite de memoria en bytes (default: 5 MB).
    init(countLimit: Int = 50, totalCostLimit: Int = 5 * 1024 * 1024) {
        cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    // MARK: - Cache Operations
    
    /// Almacena un resultado OCR en el cache.
    ///
    /// - Parameters:
    ///   - text: Texto reconocido.
    ///   - key: Clave de cache (hash del frame).
    func store(_ text: String, for key: String) {
        let entry = CacheEntry(text: text)
        let cost = text.utf8.count
        cache.setObject(entry, forKey: key as NSString, cost: cost)
    }
    
    /// Recupera un resultado OCR del cache.
    ///
    /// - Parameter key: Clave de cache (hash del frame).
    /// - Returns: Texto almacenado, o `nil` si no existe o expiró.
    func get(for key: String) -> String? {
        guard let entry = cache.object(forKey: key as NSString) else {
            return nil
        }
        
        // Check if entry has expired (30 seconds TTL)
        if Date().timeIntervalSince(entry.timestamp) > 30 {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        
        return entry.text
    }
    
    /// Limpia todo el cache.
    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - CacheEntry

/// Entrada del cache con timestamp para expiración.
private final class CacheEntry: NSObject {
    let text: String
    let timestamp: Date
    
    init(text: String) {
        self.text = text
        self.timestamp = Date()
    }
}
