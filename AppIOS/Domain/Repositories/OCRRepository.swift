
import Foundation
import CoreImage


public protocol OCRRepository: Sendable {
    
  
    func recognizeText(from pixelBuffer: CVPixelBuffer) async throws -> String
    
  
    func readProductLabel(from pixelBuffer: CVPixelBuffer) async throws -> LabelInfo
    

    func readCurrentFrame() async throws -> LabelInfo
}
