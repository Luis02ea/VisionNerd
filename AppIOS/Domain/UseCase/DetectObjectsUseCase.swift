
import Foundation


public final class DetectObjectsUseCase: Sendable {
    
    private let repository: ObjectDetectionRepository

    public init(repository: ObjectDetectionRepository) {
        self.repository = repository
    }
    

    public func execute(fps: Int = 1) -> AsyncStream<[DetectedObject]> {
        Task {
            await repository.setTargetFPS(fps)
        }
        return repository.startDetection()
    }
    
    public func stop() async {
        await repository.stopDetection()
    }

    public func search(for query: String) async -> [DetectedObject] {
        await repository.searchForObject(query: query)
    }

    public func nearestObject() async -> DetectedObject? {
        await repository.getNearestObject()
    }
}
