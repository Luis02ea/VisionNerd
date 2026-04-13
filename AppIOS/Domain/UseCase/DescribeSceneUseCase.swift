//
//  DescribeSceneUseCase.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//


import Foundation


public final class DescribeSceneUseCase: Sendable {
    
    private let sceneRepository: SceneDescriptionRepository
    

    public init(sceneRepository: SceneDescriptionRepository) {
        self.sceneRepository = sceneRepository
    }
    

    public func execute() async throws -> String {
        try await sceneRepository.describeCurrentScene()
    }
}
