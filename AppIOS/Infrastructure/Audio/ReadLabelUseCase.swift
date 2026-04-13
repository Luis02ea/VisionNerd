
import Foundation


public final class ReadLabelUseCase: Sendable {
    
    private let ocrRepository: OCRRepository
    

    public init(ocrRepository: OCRRepository) {
        self.ocrRepository = ocrRepository
    }
    
   
    public func execute() async throws -> LabelInfo {
        try await ocrRepository.readCurrentFrame()
    }

    public func executeAndSummarize() async throws -> String {
        let labelInfo = try await ocrRepository.readCurrentFrame()
        return labelInfo.spokenSummary
    }
}
