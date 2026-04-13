// MARK: - NLUParser.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import NaturalLanguage


public struct NLUParser: Sendable {
    
    
    private static let intentPatterns: [(pattern: String, intentBuilder: (String, [String]) -> UserIntent)] = [
        (
            #"(?i)\b(cancelar|cancela|detener|deten|para|parar|stop)\b"#,
            { _, _ in .cancel }
        ),
        (
            #"(?i)\b(?:buscar?|encuentra|busco|necesito|quiero|dame|dónde está|donde esta|donde hay)\s+(.+)"#,
            { fullText, groups in
                let query = groups.first ?? ""
                let cleanQuery = NLUParser.cleanSearchQuery(query)
                let filters = DietaryFilter.extract(from: fullText)
                return .search(query: cleanQuery, filters: filters)
            }
        ),
        (
            #"(?i)\b(qué hay|que hay|qué ves|que ves|qué tienes|describe|describir|describeme|escena|entorno|alrededor)\b"#,
            { _, _ in .describeScene }
        ),
        (
            #"(?i)\b(leer?|lee|lectura|texto|etiqueta|ingredientes|información nutricional|informacion nutricional)\b"#,
            { _, _ in .readLabel }
        ),
        (
            #"(?i)\b(distancia|lejos|cerca|qué tan lejos|que tan lejos|a cuánto|a cuanto)\b"#,
            { _, _ in .getDistance }
        )
    ]
   
    public static func parse(_ text: String) -> UserIntent {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            return .unknown(rawText: "")
        }
        
        for (pattern, builder) in intentPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(
                in: trimmedText,
                range: NSRange(trimmedText.startIndex..., in: trimmedText)
               ) {
                
                var groups: [String] = []
                for i in 1..<match.numberOfRanges {
                    if let range = Range(match.range(at: i), in: trimmedText) {
                        groups.append(String(trimmedText[range]))
                    }
                }
                
                return builder(trimmedText, groups)
            }
        }
        
        return analyzeWithNLTagger(text: trimmedText)
    }
    
 
    private static func cleanSearchQuery(_ query: String) -> String {
        var cleaned = query.lowercased()
        
        for filter in DietaryFilter.allCases {
            for keyword in filter.keywords {
                cleaned = cleaned.replacingOccurrences(of: keyword, with: "")
            }
        }
        
        let stopWords = ["el", "la", "los", "las", "un", "una", "unos", "unas",
                         "de", "del", "con", "que", "por favor", "por", "para"]
        for word in stopWords {
            cleaned = cleaned.replacingOccurrences(
                of: #"\b\#(word)\b"#,
                with: "",
                options: .regularExpression
            )
        }
        
        cleaned = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? query.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }
    
  
    private static func analyzeWithNLTagger(text: String) -> UserIntent {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var hasVerb = false
        var nouns: [String] = []
        
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, tokenRange in
            let word = String(text[tokenRange])
            if tag == .verb {
                hasVerb = true
            } else if tag == .noun {
                nouns.append(word)
            }
            return true
        }
        
        if hasVerb && !nouns.isEmpty {
            let query = nouns.joined(separator: " ")
            let filters = DietaryFilter.extract(from: text)
            return .search(query: query, filters: filters)
        }
        
        return .unknown(rawText: text)
    }
}
