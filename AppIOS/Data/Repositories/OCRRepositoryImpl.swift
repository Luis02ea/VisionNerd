
import Foundation
import Vision
import NaturalLanguage

final class OCRRepositoryImpl: OCRRepository, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let cameraService: CameraService
    private let cache: OCRCache
    
    init(cameraService: CameraService, cache: OCRCache = OCRCache()) {
        self.cameraService = cameraService
        self.cache = cache
    }
    
    
    func recognizeText(from pixelBuffer: CVPixelBuffer) async throws -> String {
        let frameHash = hashPixelBuffer(pixelBuffer)
        if let cached = cache.get(for: frameHash) {
            return cached
        }
        
        let text = try await performOCR(on: pixelBuffer)
        cache.store(text, for: frameHash)
        return text
    }
    
    func readProductLabel(from pixelBuffer: CVPixelBuffer) async throws -> LabelInfo {
        let rawText = try await recognizeText(from: pixelBuffer)
        return structureLabel(from: rawText)
    }
    
    func readCurrentFrame() async throws -> LabelInfo {
        guard let pixelBuffer = cameraService.captureSnapshot() else {
            throw OCRError.noFrameAvailable
        }
        return try await readProductLabel(from: pixelBuffer)
    }
    

    private func performOCR(on pixelBuffer: CVPixelBuffer) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es", "en"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
    

    private func structureLabel(from rawText: String) -> LabelInfo {
        let lines = rawText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        
        return LabelInfo(
            productName: extractProductName(from: lines),
            ingredients: extractIngredients(from: rawText),
            nutritionInfo: extractNutritionInfo(from: rawText),
            expirationDate: extractExpirationDate(from: rawText),
            rawText: rawText
        )
    }
    
    private func extractProductName(from lines: [String]) -> String? {

        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count >= 3 else { continue }
            
            let skipPrefixes = ["ingredientes", "información", "informacion", "tabla", "contenido",
                                "calorías", "calorias", "grasa", "proteín", "carbohidrat"]
            let lowercased = trimmed.lowercased()
            if skipPrefixes.contains(where: { lowercased.hasPrefix($0) }) { continue }
            
            return trimmed
        }
        return nil
    }
    
    private func extractIngredients(from text: String) -> [String] {
        let lowercased = text.lowercased()
        
        guard let range = lowercased.range(of: "ingredientes") else {
            return []
        }
        
        let afterIngredients = String(lowercased[range.upperBound...])
        
        let sectionEnders = ["información nutricional", "informacion nutricional",
                             "tabla nutricional", "modo de uso", "conservar",
                             "contenido neto", "hecho en", "elaborado"]
        
        var ingredientText = afterIngredients
        for ender in sectionEnders {
            if let enderRange = ingredientText.range(of: ender) {
                ingredientText = String(ingredientText[..<enderRange.lowerBound])
                break
            }
        }
        
        let ingredients = ingredientText
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 2 }
            .prefix(5)
        
        return Array(ingredients)
    }
    
    private func extractNutritionInfo(from text: String) -> NutritionInfo? {
        let lowercased = text.lowercased()
        
        let calories = extractNutrientValue(from: lowercased, keywords: ["calorías", "calorias", "energía", "energia", "kcal"])
        let fat = extractNutrientValue(from: lowercased, keywords: ["grasa total", "grasas totales", "grasa"])
        let carbs = extractNutrientValue(from: lowercased, keywords: ["carbohidrato", "carbohidratos", "hidratos de carbono"])
        let protein = extractNutrientValue(from: lowercased, keywords: ["proteína", "proteina", "proteínas", "proteinas"])
        let sugar = extractNutrientValue(from: lowercased, keywords: ["azúcar", "azucar", "azúcares", "azucares"])
        
        guard calories != nil || fat != nil || carbs != nil || protein != nil || sugar != nil else {
            return nil
        }
        
        return NutritionInfo(
            calories: calories,
            totalFat: fat,
            carbohydrates: carbs,
            protein: protein,
            sugar: sugar
        )
    }
    
    private func extractNutrientValue(from text: String, keywords: [String]) -> String? {
        for keyword in keywords {
            guard let range = text.range(of: keyword) else { continue }
            
            let afterKeyword = String(text[range.upperBound...]).prefix(30)
            
            let numberPattern = #"[\s:]*(\d+[.,]?\d*\s*(?:kcal|cal|g|mg|ml|%)?)"#
            if let regex = try? NSRegularExpression(pattern: numberPattern),
               let match = regex.firstMatch(
                in: String(afterKeyword),
                range: NSRange(afterKeyword.startIndex..., in: afterKeyword)
               ),
               let valueRange = Range(match.range(at: 1), in: afterKeyword) {
                return String(afterKeyword[valueRange]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    private func extractExpirationDate(from text: String) -> String? {
        let datePatterns = [
            #"\d{2}/\d{2}/\d{4}"#,      
            #"\d{2}-\d{2}-\d{4}"#,      
            #"\d{2}\.\d{2}\.\d{4}"#,    
            #"\d{4}/\d{2}/\d{2}"#,      
            #"\d{2}/\d{2}/\d{2}"#       
        ]
        
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
               ),
               let range = Range(match.range, in: text) {
                
                let surroundingText = extractSurroundingText(text: text, around: range, radius: 50)
                let expirationKeywords = ["vencimiento", "vence", "caducidad", "caduca",
                                          "consumir antes", "exp", "best before", "use by"]
                
                if expirationKeywords.contains(where: { surroundingText.lowercased().contains($0) }) {
                    return String(text[range])
                }
                
                return String(text[range])
            }
        }
        return nil
    }
    
    private func extractSurroundingText(text: String, around range: Range<String.Index>, radius: Int) -> String {
        let startDistance = text.distance(from: text.startIndex, to: range.lowerBound)
        let startOffset = max(0, startDistance - radius)
        let start = text.index(text.startIndex, offsetBy: startOffset)
        
        let endDistance = text.distance(from: text.startIndex, to: range.upperBound)
        let endOffset = min(text.count, endDistance + radius)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        
        return String(text[start..<end])
    }
        
    private func hashPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> String {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return UUID().uuidString
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var hash: UInt64 = 0
        
        let samplePoints = [
            (width / 4, height / 4),
            (width / 2, height / 2),
            (3 * width / 4, 3 * height / 4),
            (width / 2, height / 4),
            (width / 4, height / 2)
        ]
        
        for (x, y) in samplePoints {
            let offset = y * bytesPerRow + x * 4
            let pixel = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt32.self).pointee
            hash = hash &* 31 &+ UInt64(pixel)
        }
        
        return String(hash)
    }
}

enum OCRError: LocalizedError {
    case noFrameAvailable
    case recognitionFailed(String)
    case structuringFailed
    
    var errorDescription: String? {
        switch self {
        case .noFrameAvailable:
            return "No hay frame disponible de la cámara para OCR."
        case .recognitionFailed(let detail):
            return "El reconocimiento de texto falló: \(detail)"
        case .structuringFailed:
            return "No se pudo estructurar la información de la etiqueta."
        }
    }
}
