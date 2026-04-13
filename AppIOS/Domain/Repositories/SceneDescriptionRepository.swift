
import Foundation


public protocol SceneDescriptionRepository: Sendable {
    
 
    func describeCurrentScene() async throws -> String
    

    func describeLocally(objects: [DetectedObject]) -> String
    
 
    func describeWithCloudAI(imageData: Data) async throws -> String
}
