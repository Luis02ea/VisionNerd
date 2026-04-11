// MARK: - NLUParser.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import NaturalLanguage

// MARK: - NLUParser

/// Motor de comprensión de lenguaje natural (NLU) para comandos de voz.
///
/// Transforma texto reconocido por `SFSpeechRecognizer` en intenciones
/// estructuradas (`UserIntent`) usando una combinación de:
/// - Expresiones regulares para patrones de comando
/// - `NLTagger` para análisis lingüístico
/// - Extracción de filtros dietéticos
///
/// ## Intenciones reconocidas
/// | Comando del usuario          | Intención resultante                |
/// |------------------------------|-------------------------------------|
/// | "buscar leche sin gluten"    | `.search(query: "leche", filters: [.glutenFree])` |
/// | "¿qué hay delante?"         | `.describeScene`                    |
/// | "leer etiqueta"             | `.readLabel`                        |
/// | "¿a qué distancia?"         | `.getDistance`                      |
/// | "cancelar"                  | `.cancel`                           |
public struct NLUParser: Sendable {
    
    // MARK: - Intent Patterns
    
    /// Patrones regex para cada intención, ordenados por prioridad.
    private static let intentPatterns: [(pattern: String, intentBuilder: (String, [String]) -> UserIntent)] = [
        // Cancel
        (
            #"(?i)\b(cancelar|cancela|detener|deten|para|parar|stop)\b"#,
            { _, _ in .cancel }
        ),
        // Search
        (
            #"(?i)\b(?:buscar?|encuentra|busco|necesito|quiero|dame|dónde está|donde esta|donde hay)\s+(.+)"#,
            { fullText, groups in
                let query = groups.first ?? ""
                let cleanQuery = NLUParser.cleanSearchQuery(query)
                let filters = DietaryFilter.extract(from: fullText)
                return .search(query: cleanQuery, filters: filters)
            }
        ),
        // Describe scene
        (
            #"(?i)\b(qué hay|que hay|qué ves|que ves|qué tienes|describe|describir|describeme|escena|entorno|alrededor)\b"#,
            { _, _ in .describeScene }
        ),
        // Read label
        (
            #"(?i)\b(leer?|lee|lectura|texto|etiqueta|ingredientes|información nutricional|informacion nutricional)\b"#,
            { _, _ in .readLabel }
        ),
        // Get distance
        (
            #"(?i)\b(distancia|lejos|cerca|qué tan lejos|que tan lejos|a cuánto|a cuanto)\b"#,
            { _, _ in .getDistance }
        )
    ]
    
    // MARK: - Public API
    
    /// Parsea un texto reconocido por voz y extrae la intención del usuario.
    ///
    /// - Parameter text: Texto transcrito del reconocimiento de voz.
    /// - Returns: La intención del usuario.
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
                
                // Extract capture groups
                var groups: [String] = []
                for i in 1..<match.numberOfRanges {
                    if let range = Range(match.range(at: i), in: trimmedText) {
                        groups.append(String(trimmedText[range]))
                    }
                }
                
                return builder(trimmedText, groups)
            }
        }
        
        // Fallback: use NLTagger for additional analysis
        return analyzeWithNLTagger(text: trimmedText)
    }
    
    // MARK: - Private Helpers
    
    /// Limpia la query de búsqueda eliminando filtros dietéticos y artículos.
    private static func cleanSearchQuery(_ query: String) -> String {
        var cleaned = query.lowercased()
        
        // Remove dietary filter keywords from query
        for filter in DietaryFilter.allCases {
            for keyword in filter.keywords {
                cleaned = cleaned.replacingOccurrences(of: keyword, with: "")
            }
        }
        
        // Remove common articles and prepositions
        let stopWords = ["el", "la", "los", "las", "un", "una", "unos", "unas",
                         "de", "del", "con", "que", "por favor", "por", "para"]
        for word in stopWords {
            // Only remove as standalone words
            cleaned = cleaned.replacingOccurrences(
                of: #"\b\#(word)\b"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Clean up whitespace
        cleaned = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? query.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }
    
    /// Analiza el texto con NLTagger como fallback.
    ///
    /// Usa análisis de partes del habla (POS tagging) para intentar
    /// extraer una intención cuando los patrones regex no coinciden.
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
        
        // If we found nouns with a verb, treat as a search
        if hasVerb && !nouns.isEmpty {
            let query = nouns.joined(separator: " ")
            let filters = DietaryFilter.extract(from: text)
            return .search(query: query, filters: filters)
        }
        
        return .unknown(rawText: text)
    }
}
