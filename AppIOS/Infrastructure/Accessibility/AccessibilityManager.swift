//
//  AccessibilityManager.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - AccessibilityManager.swift
// GuideVision — Infrastructure Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import UIKit
import SwiftUI

// MARK: - AccessibilityManager

/// Gestor centralizado de accesibilidad para la aplicación.
///
/// Observa el estado de VoiceOver y proporciona utilidades para:
/// - Anuncios de accesibilidad sin cambio de foco
/// - Observación de cambios en VoiceOver
/// - Helpers para configurar accesibilidad en views
///
/// ## Uso
/// ```swift
/// let manager = AccessibilityManager.shared
/// manager.announce("Producto encontrado")
/// ```
@Observable
final class AccessibilityManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// Instancia compartida del gestor de accesibilidad.
    static let shared = AccessibilityManager()
    
    // MARK: - Properties
    
    /// Indica si VoiceOver está activo.
    private(set) var isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning
    
    /// Indica si el usuario prefiere transparencia reducida.
    private(set) var prefersReducedTransparency: Bool = UIAccessibility.isReduceTransparencyEnabled
    
    /// Indica si el usuario prefiere movimiento reducido.
    private(set) var prefersReducedMotion: Bool = UIAccessibility.isReduceMotionEnabled
    
    /// Último anuncio realizado (para testing).
    private(set) var lastAnnouncement: String?
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Observers
    
    /// Registra observadores para cambios en el estado de accesibilidad.
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceTransparencyChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc private func voiceOverStatusChanged() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    }
    
    @objc private func reduceTransparencyChanged() {
        prefersReducedTransparency = UIAccessibility.isReduceTransparencyEnabled
    }
    
    @objc private func reduceMotionChanged() {
        prefersReducedMotion = UIAccessibility.isReduceMotionEnabled
    }
    
    // MARK: - Announcements
    
    /// Realiza un anuncio de accesibilidad sin cambiar el foco de VoiceOver.
    ///
    /// El anuncio se escucha inmediatamente y no interrumpe la navegación
    /// actual del usuario con VoiceOver.
    ///
    /// - Parameter message: Texto a anunciar.
    func announce(_ message: String) {
        lastAnnouncement = message
        
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .announcement,
                argument: message
            )
        }
    }
    
    /// Realiza un anuncio con prioridad que interrumpe anuncios previos.
    ///
    /// - Parameter message: Texto a anunciar con prioridad.
    @available(iOS 17.0, *)
    func announceWithPriority(_ message: String) {
        lastAnnouncement = message
        
        DispatchQueue.main.async {
            let announcement = AttributedString(message)
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
    
    /// Mueve el foco de VoiceOver a un elemento específico.
    ///
    /// - Parameter element: El elemento UI al que mover el foco.
    func moveFocus(to element: Any) {
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: element
            )
        }
    }
    
    /// Notifica que el layout de la pantalla cambió.
    func notifyLayoutChanged() {
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: nil
            )
        }
    }
    
    /// Notifica que la pantalla cambió completamente.
    func notifyScreenChanged() {
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .screenChanged,
                argument: nil
            )
        }
    }
}

// MARK: - SwiftUI View Extension for Accessibility

extension View {
    
    /// Configura la accesibilidad completa de una vista para GuideVision.
    ///
    /// - Parameters:
    ///   - label: Etiqueta descriptiva.
    ///   - hint: Pista sobre qué hace la acción.
    ///   - value: Valor actual del elemento.
    ///   - traits: Rasgos de accesibilidad del elemento.
    /// - Returns: Vista modificada con accesibilidad configurada.
    func guideVisionAccessibility(
        label: String,
        hint: String = "",
        value: String = "",
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint.isEmpty ? label : hint)
            .accessibilityValue(value)
            .accessibilityAddTraits(traits)
    }
    
    /// Agrega acciones personalizadas de accesibilidad de GuideVision.
    ///
    /// - Parameters:
    ///   - onSearch: Acción al activar "Buscar".
    ///   - onDescribe: Acción al activar "Describir escena".
    ///   - onReadLabel: Acción al activar "Leer etiqueta".
    /// - Returns: Vista con acciones personalizadas.
    func guideVisionCustomActions(
        onSearch: @escaping () -> Void,
        onDescribe: @escaping () -> Void,
        onReadLabel: @escaping () -> Void
    ) -> some View {
        self
            .accessibilityAction(named: "Buscar producto") { onSearch() }
            .accessibilityAction(named: "Describir escena") { onDescribe() }
            .accessibilityAction(named: "Leer etiqueta") { onReadLabel() }
    }
}
