// MARK: - ReadLabelUseCase.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - ReadLabelUseCase

/// Caso de uso para la lectura de etiquetas de productos mediante OCR.
///
/// Coordina la captura de frame, reconocimiento de texto y
/// estructuración de la información de la etiqueta.
public final class ReadLabelUseCase: Sendable {
    
    private let ocrRepository: OCRRepository
    
    /// Crea una nueva instancia del caso de uso.
    ///
    /// - Parameter ocrRepository: Repositorio de OCR.
    public init(ocrRepository: OCRRepository) {
        self.ocrRepository = ocrRepository
    }
    
    /// Lee la etiqueta del producto visible en la cámara.
    ///
    /// - Returns: Información estructurada de la etiqueta.
    /// - Throws: Error si la lectura falla.
    public func execute() async throws -> LabelInfo {
        try await ocrRepository.readCurrentFrame()
    }
    
    /// Lee la etiqueta y genera un resumen hablado.
    ///
    /// - Returns: Texto listo para síntesis de voz con la información de la etiqueta.
    /// - Throws: Error si la lectura falla.
    public func executeAndSummarize() async throws -> String {
        let labelInfo = try await ocrRepository.readCurrentFrame()
        return labelInfo.spokenSummary
    }
}
