//
//  AccessibilityManager.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//


import Foundation
import UIKit
import SwiftUI


@Observable
final class AccessibilityManager: @unchecked Sendable {
    
    
    static let shared = AccessibilityManager()
    
    
    private(set) var isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning
    
    private(set) var prefersReducedTransparency: Bool = UIAccessibility.isReduceTransparencyEnabled
    
    private(set) var prefersReducedMotion: Bool = UIAccessibility.isReduceMotionEnabled
    
    private(set) var lastAnnouncement: String?
    
    
    private init() {
        setupObservers()
    }
    

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
    
    
    @objc private func voiceOverStatusChanged() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    }
    
    @objc private func reduceTransparencyChanged() {
        prefersReducedTransparency = UIAccessibility.isReduceTransparencyEnabled
    }
    
    @objc private func reduceMotionChanged() {
        prefersReducedMotion = UIAccessibility.isReduceMotionEnabled
    }
    
   
    func announce(_ message: String) {
        lastAnnouncement = message
        
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .announcement,
                argument: message
            )
        }
    }
    

    @available(iOS 17.0, *)
    func announceWithPriority(_ message: String) {
        lastAnnouncement = message
        
        DispatchQueue.main.async {
            let announcement = AttributedString(message)
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
    

    func moveFocus(to element: Any) {
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: element
            )
        }
    }
    
    func notifyLayoutChanged() {
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: nil
            )
        }
    }
    
    func notifyScreenChanged() {
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: .screenChanged,
                argument: nil
            )
        }
    }
}


extension View {
    

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
