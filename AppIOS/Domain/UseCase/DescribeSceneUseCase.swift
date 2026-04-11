//
//  DescribeSceneUseCase.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - DescribeSceneUseCase.swift
// GuideVision — Domain Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation

// MARK: - DescribeSceneUseCase

/// Caso de uso para describir verbalmente la escena actual.
///
/// Combina detección local de objetos con IA en la nube como fallback
/// para generar una descripción completa de lo que la cámara está capturando.
public final class DescribeSceneUseCase: Sendable {
    
    private let sceneRepository: SceneDescriptionRepository
    
    /// Crea una nueva instancia del caso de uso.
    ///
    /// - Parameter sceneRepository: Repositorio de descripción de escenas.
    public init(sceneRepository: SceneDescriptionRepository) {
        self.sceneRepository = sceneRepository
    }
    
    /// Describe la escena actual.
    ///
    /// - Returns: Descripción textual lista para síntesis de voz.
    /// - Throws: Error si la descripción falla.
    public func execute() async throws -> String {
        try await sceneRepository.describeCurrentScene()
    }
}
