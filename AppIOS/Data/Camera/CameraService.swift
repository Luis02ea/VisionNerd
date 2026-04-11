//
//  CameraService.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - CameraService.swift
// GuideVision — Data Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import AVFoundation
import CoreImage
import UIKit

final class CameraService: NSObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Sesión de captura de AVFoundation.
    let captureSession = AVCaptureSession()
    
    /// Cola serial dedicada para output de video.
    private let videoOutputQueue = DispatchQueue(
        label: "com.guidevision.camera.videooutput",
        qos: .userInitiated
    )
    
    /// Cola serial para configuración de la sesión.
    private let sessionQueue = DispatchQueue(
        label: "com.guidevision.camera.session",
        qos: .userInitiated
    )
    
    /// Output de datos de video.
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    /// Continuación del stream de frames para async/await.
    private var frameContinuation: AsyncStream<CMSampleBuffer>.Continuation?
    
    /// Stream asíncrono de frames de cámara.
    private(set) var frameStream: AsyncStream<CMSampleBuffer>!
    
    /// Último frame capturado para acceso directo.
    private(set) var latestPixelBuffer: CVPixelBuffer?
    
    /// Flag para indicar si la sesión está activa.
    private(set) var isRunning = false
    
    /// Estado de autorización de la cámara.
    private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupFrameStream()
    }
    
    // MARK: - Frame Stream Setup
    
    /// Configura el AsyncStream para publicar frames de cámara.
    private func setupFrameStream() {
        frameStream = AsyncStream<CMSampleBuffer> { [weak self] continuation in
            self?.frameContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                // Cleanup when stream is cancelled
            }
        }
    }
    
    // MARK: - Authorization
    
    /// Solicita autorización para usar la cámara.
    ///
    /// - Returns: `true` si el usuario concedió acceso, `false` en caso contrario.
    func requestAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Session Configuration
    
    /// Configura la sesión de captura con cámara trasera a 1080p.
    ///
    /// - Throws: `CameraError` si la configuración falla.
    func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Set session preset
        captureSession.sessionPreset = .hd1920x1080
        
        // Add video input (back camera)
        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw CameraError.deviceNotAvailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        
        guard captureSession.canAddInput(videoInput) else {
            throw CameraError.cannotAddInput
        }
        captureSession.addInput(videoInput)
        
        // Configure video output
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        guard captureSession.canAddOutput(videoDataOutput) else {
            throw CameraError.cannotAddOutput
        }
        captureSession.addOutput(videoDataOutput)
        
        // Set video orientation
        if let connection = videoDataOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
        
        // Configure frame rate (30fps)
        try configureFrameRate(device: videoDevice, desiredFPS: 30)
    }
    
    /// Configura el frame rate del dispositivo de cámara.
    private func configureFrameRate(device: AVCaptureDevice, desiredFPS: Int) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        let desiredDuration = CMTimeMake(value: 1, timescale: Int32(desiredFPS))
        
        for range in device.activeFormat.videoSupportedFrameRateRanges {
            if range.minFrameDuration <= desiredDuration && 
               range.maxFrameDuration >= desiredDuration {
                device.activeVideoMinFrameDuration = desiredDuration
                device.activeVideoMaxFrameDuration = desiredDuration
                break
            }
        }
    }
    
    // MARK: - Session Lifecycle
    
    /// Inicia la sesión de captura.
    func startSession() async {
        guard !isRunning else { return }
        
        let authorized = await requestAuthorization()
        guard authorized else { return }
        
        do {
            try configureSession()
        } catch {
            print("Error configuring camera session: \(error)")
            return
        }
        
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
            self?.isRunning = true
        }
    }
    
    /// Detiene la sesión de captura.
    func stopSession() {
        guard isRunning else { return }
        
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            self?.isRunning = false
        }
        
        frameContinuation?.finish()
    }
    
    /// Captura un snapshot del frame actual.
    ///
    /// - Returns: El CVPixelBuffer del último frame, o `nil` si no hay frames disponibles.
    func captureSnapshot() -> CVPixelBuffer? {
        return latestPixelBuffer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Store latest pixel buffer for snapshot access
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            latestPixelBuffer = pixelBuffer
        }
        
        // Publish to async stream
        frameContinuation?.yield(sampleBuffer)
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frames dropped — this is expected under heavy load
    }
}

// MARK: - CameraError

/// Errores específicos del servicio de cámara.
enum CameraError: LocalizedError {
    case deviceNotAvailable
    case cannotAddInput
    case cannotAddOutput
    case notAuthorized
    case configurationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "No se encontró una cámara disponible en este dispositivo."
        case .cannotAddInput:
            return "No se pudo agregar la entrada de video a la sesión."
        case .cannotAddOutput:
            return "No se pudo agregar la salida de video a la sesión."
        case .notAuthorized:
            return "No se tiene permiso para acceder a la cámara."
        case .configurationFailed(let detail):
            return "Error de configuración de cámara: \(detail)"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension CameraService {
    
    /// Creates a CameraService instance for SwiftUI previews.
    static func preview() -> CameraService {
        CameraService()
    }
}
#endif
