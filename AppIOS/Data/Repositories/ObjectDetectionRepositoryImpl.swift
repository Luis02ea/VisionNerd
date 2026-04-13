//
//  ObjectDetectionRepositoryImpl.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

import Foundation
import AVFoundation

final class ObjectDetectionRepositoryImpl: ObjectDetectionRepository, @unchecked Sendable {
    
    
    private let cameraService: CameraService
    private let inferenceEngine: InferenceEngine
    private var detectionTask: Task<Void, Never>?
    private var currentFPS: Int = 1
    private var latestDetections: [DetectedObject] = []
    private var detectionContinuation: AsyncStream<[DetectedObject]>.Continuation?
    
  
    init(cameraService: CameraService, inferenceEngine: InferenceEngine) {
        self.cameraService = cameraService
        self.inferenceEngine = inferenceEngine
    }
    
    
    func startDetection() -> AsyncStream<[DetectedObject]> {
        detectionTask?.cancel()
        
        let stream = AsyncStream<[DetectedObject]> { [weak self] continuation in
            self?.detectionContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                self?.detectionTask?.cancel()
            }
        }
        
        detectionTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await sampleBuffer in cameraService.frameStream {
                guard !Task.isCancelled else { break }
                
                let sleepDuration = UInt64(1_000_000_000 / max(1, self.currentFPS))
                try? await Task.sleep(nanoseconds: sleepDuration)
                
                guard !Task.isCancelled else { break }
                
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    continue
                }
                
                do {
                    let objects = try await inferenceEngine.detectObjects(in: pixelBuffer)
                    self.latestDetections = objects
                    
                    // Yield on MainActor to ensure thread safety for @Observable consumers
                    await MainActor.run {
                        self.detectionContinuation?.yield(objects)
                    }
                } catch {
                    print("[ObjectDetection] Inference error: \(error.localizedDescription)")
                }
            }
        }
        
        return stream
    }
    
    func stopDetection() async {
        detectionTask?.cancel()
        detectionTask = nil
        detectionContinuation?.finish()
        detectionContinuation = nil
    }
    
    func setTargetFPS(_ fps: Int) async {
        currentFPS = max(1, min(fps, 30))
        await inferenceEngine.setTargetFPS(currentFPS)
    }
    
    func searchForObject(query: String) async -> [DetectedObject] {
        let lowercasedQuery = query.lowercased()
        return latestDetections
            .filter { $0.label.lowercased().contains(lowercasedQuery) ||
                      lowercasedQuery.contains($0.label.lowercased()) }
            .sorted { $0.confidence > $1.confidence }
    }
    
    func getNearestObject() async -> DetectedObject? {
        latestDetections
            .sorted { $0.boundingBox.height * $0.boundingBox.width >
                      $1.boundingBox.height * $1.boundingBox.width }
            .first
    }
}
