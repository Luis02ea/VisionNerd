//
//  AppDelegate.swift
//  AppIOS
//
//  Created by Alumno on 10/04/26.
//
import UIKit
import SwiftUI
import AVFoundation
import CoreML
import Combine
import Os


class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        if UIAccessibility.isVoiceOverRunning {
            print("[App] VoiceOver is active — app will prioritize audio feedback")
        }
        
        return true
    }
    
    @objc private func voiceOverStatusChanged() {
        let isRunning = UIAccessibility.isVoiceOverRunning
        print("[App] VoiceOver status changed: \(isRunning ? "active" : "inactive")")
    }
}
