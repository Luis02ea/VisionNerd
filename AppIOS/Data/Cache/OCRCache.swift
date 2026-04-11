//
//  OCRCache.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//


import Foundation

final class OCRCache: @unchecked Sendable {
    
  
    private let cache: NSCache<NSString, CacheEntry>
    
 
    init(countLimit: Int = 50, totalCostLimit: Int = 5 * 1024 * 1024) {
        cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
 
    func store(_ text: String, for key: String) {
        let entry = CacheEntry(text: text)
        let cost = text.utf8.count
        cache.setObject(entry, forKey: key as NSString, cost: cost)
    }
    
   
    func get(for key: String) -> String? {
        guard let entry = cache.object(forKey: key as NSString) else {
            return nil
        }
        
        if Date().timeIntervalSince(entry.timestamp) > 30 {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        
        return entry.text
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

private final class CacheEntry: NSObject {
    let text: String
    let timestamp: Date
    
    init(text: String) {
        self.text = text
        self.timestamp = Date()
    }
}
