// MARK: - OCRRepository.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import CoreImage

// MARK: - OCRRepository

/// Protocolo que define la interfaz para reconocimiento óptico de caracteres (OCR).
///
/// Utiliza Vision framework (`VNRecognizeTextRequest`) para extraer texto
/// de los frames de la cámara, con procesamiento de NLTagger para
/// estructurar la información de etiquetas de productos.
public protocol OCRRepository: Sendable {
    
    /// Reconoce texto en un frame capturado de la cámara.
    ///
    /// - Parameter pixelBuffer: Buffer del frame de la cámara.
    /// - Returns: Texto reconocido completo.
    /// - Throws: Error si el reconocimiento falla.
    func recognizeText(from pixelBuffer: CVPixelBuffer) async throws -> String
    
    /// Reconoce y estructura la información de una etiqueta de producto.
    ///
    /// Procesa el texto reconocido para extraer nombre del producto,
    /// ingredientes, información nutricional y fecha de vencimiento.
    ///
    /// - Parameter pixelBuffer: Buffer del frame de la cámara.
    /// - Returns: Información estructurada de la etiqueta.
    /// - Throws: Error si el reconocimiento falla.
    func readProductLabel(from pixelBuffer: CVPixelBuffer) async throws -> LabelInfo
    
    /// Captura el frame actual de la cámara y ejecuta OCR.
    ///
    /// Conveniencia que captura un frame fresh y ejecuta reconocimiento.
    ///
    /// - Returns: Información de la etiqueta del frame actual.
    /// - Throws: Error si la captura o el reconocimiento falla.
    func readCurrentFrame() async throws -> LabelInfo
}
