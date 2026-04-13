
import Foundation


public final class SearchProductUseCase: Sendable {
    
    private let detectionRepository: ObjectDetectionRepository
    

    public init(detectionRepository: ObjectDetectionRepository) {
        self.detectionRepository = detectionRepository
    }
    
 
    public func startSearch(query: String) -> AsyncStream<[DetectedObject]> {
        Task {
            await detectionRepository.setTargetFPS(5)
        }
        return detectionRepository.startDetection()
    }

    public func filterResults(_ objects: [DetectedObject], for query: String) -> [DetectedObject] {
        let lowercasedQuery = query.lowercased()
        return objects.filter { object in
            object.label.lowercased().contains(lowercasedQuery) ||
            lowercasedQuery.contains(object.label.lowercased())
        }
    }
    
    public func stopSearch() async {
        await detectionRepository.setTargetFPS(1)
    }
}
