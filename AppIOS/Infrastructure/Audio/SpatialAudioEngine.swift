//
//  SpatialAudioEngine.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//

// MARK: - SpatialAudioEngine.swift
// GuideVision — Infrastructure Layer
// Copyright © 2026 GuideVision. All rights reserved.

import Foundation
import AVFoundation
import PHASE

// MARK: - SpatialAudioEngine

/// Motor de audio espacial 3D usando el framework PHASE de Apple.
///
/// Mapea la posición de un objeto detectado en el frame de la cámara
/// a audio posicional 3D, permitiendo al usuario localizar objetos
/// mediante sonido.
///
/// ## Mapeo de posición
/// | Posición horizontal (boundingBox.midX) | Azimuth     |
/// |----------------------------------------|-------------|
/// | 0.0 – 0.35 (izquierda)                | -90°        |
/// | 0.35 – 0.65 (centro)                  | 0°          |
/// | 0.65 – 1.0 (derecha)                  | +90°        |
///
/// ## Mapeo de distancia
/// | Categoría | Gain | Pitch |
/// |-----------|------|-------|
/// | .near     | 1.0  | 1.05  |
/// | .medium   | 0.65 | 1.0   |
/// | .far      | 0.3  | 0.95  |
///
/// ## Audio Session
/// Usa `AVAudioSession.Category.playback` con `.mixWithOthers`
/// para nunca interrumpir VoiceOver.
final class SpatialAudioEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Motor PHASE para audio espacial.
    private var phaseEngine: PHASEEngine?
    
    /// Listener (oídos del usuario) en el espacio 3D.
    private var listener: PHASEListener?
    
    /// Fuente de audio activa.
    private var source: PHASESource?
    
    /// Evento de sonido actual.
    private var currentSoundEvent: PHASESoundEvent?
    
    /// Flag para indicar si el motor está activo.
    private(set) var isActive: Bool = false
    
    /// La sesión de audio compartida.
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Fallback (AVAudioEngine)
    
    /// Motor AVAudio como fallback cuando PHASE no está disponible.
    private var avAudioEngine: AVAudioEngine?
    private var avEnvironmentNode: AVAudioEnvironmentNode?
    private var avPlayerNode: AVAudioPlayerNode?
    
    /// Flag que indica si estamos usando el fallback.
    private var usingFallback: Bool = false
    
    // MARK: - Initialization
    
    init() {
        configureAudioSession()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Audio Session
    
    /// Configura la sesión de audio para no interrumpir VoiceOver.
    private func configureAudioSession() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("[SpatialAudio] Error configuring audio session: \(error)")
        }
    }
    
    // MARK: - PHASE Engine Setup
    
    /// Inicia el motor de audio espacial.
    ///
    /// Intenta usar PHASE primero. Si falla, recurre a AVAudioEngine como fallback.
    func start() {
        do {
            try setupPHASEEngine()
            isActive = true
        } catch {
            print("[SpatialAudio] PHASE init failed, using AVAudio fallback: \(error)")
            setupAVAudioFallback()
            isActive = true
            usingFallback = true
        }
    }
    
    /// Configura el motor PHASE con listener y source.
    private func setupPHASEEngine() throws {
        let engine = PHASEEngine(updateMode: .automatic)
        
        // Create listener (user's ears)
        let listener = PHASEListener(engine: engine)
        listener.transform = matrix_identity_float4x4
        try engine.rootObject.addChild(listener)
        
        // Create source
        let source = PHASESource(engine: engine)
        try engine.rootObject.addChild(source)
        
        // Register sound assets
        try registerSoundAssets(engine: engine)
        
        // Start engine
        try engine.start()
        
        self.phaseEngine = engine
        self.listener = listener
        self.source = source
    }
    
    /// Registra los archivos de sonido sonar en el motor PHASE.
    private func registerSoundAssets(engine: PHASEEngine) throws {
        let soundNames = ["sonar_near", "sonar_medium", "sonar_far"]
        
        for name in soundNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "caf") {
                try engine.assetRegistry.registerSoundAsset(
                    url: url,
                    identifier: name,
                    assetType: .resident,
                    channelLayout: nil,
                    normalizationMode: .dynamic
                )
            } else {
                // Sound file not found — will use programmatic fallback
                print("[SpatialAudio] Sound file '\(name).caf' not found in bundle")
            }
        }
    }
    
    // MARK: - AVAudio Fallback
    
    /// Configura AVAudioEngine como fallback para audio espacial básico.
    private func setupAVAudioFallback() {
        let engine = AVAudioEngine()
        let environmentNode = AVAudioEnvironmentNode()
        let playerNode = AVAudioPlayerNode()
        
        engine.attach(environmentNode)
        engine.attach(playerNode)
        
        // Configure 3D audio environment
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.renderingAlgorithm = .HRTFHQ
        
        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: environmentNode, format: format)
        engine.connect(environmentNode, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            avAudioEngine = engine
            avEnvironmentNode = environmentNode
            avPlayerNode = playerNode
        } catch {
            print("[SpatialAudio] AVAudio fallback also failed: \(error)")
        }
    }
    
    // MARK: - Spatial Audio Playback
    
    /// Reproduce audio espacial basado en la posición y distancia de un objeto.
    ///
    /// - Parameter object: El objeto detectado cuya posición determina el audio espacial.
    func playSpatialAudio(for object: DetectedObject) {
        let azimuth = calculateAzimuth(from: object.horizontalPosition)
        let distance = object.estimatedDistance
        
        if usingFallback {
            playSpatialAudioFallback(azimuth: azimuth, distance: distance)
        } else {
            playSpatialAudioPHASE(azimuth: azimuth, distance: distance)
        }
    }
    
    /// Reproduce audio espacial usando PHASE.
    private func playSpatialAudioPHASE(azimuth: Float, distance: DistanceCategory) {
        guard let engine = phaseEngine, let source = source else { return }
        
        // Update source position based on azimuth
        let radians = azimuth * .pi / 180.0
        let distanceValue: Float = {
            switch distance {
            case .near:   return 1.0
            case .medium: return 3.0
            case .far:    return 6.0
            }
        }()
        
        // Position source in 3D space
        var transform = matrix_identity_float4x4
        transform.columns.3.x = sin(radians) * distanceValue
        transform.columns.3.z = -cos(radians) * distanceValue
        source.transform = transform
        
        // Select appropriate sound asset
        let soundName: String
        switch distance {
        case .near:   soundName = "sonar_near"
        case .medium: soundName = "sonar_medium"
        case .far:    soundName = "sonar_far"
        }
        
        // Stop current event before playing new one
        currentSoundEvent?.stop()
        
        // Create and play sound event
        do {
            // Try to create a channel mixer definition for spatialized playback
            let channelMixerDef = PHASEChannelMixerDefinition(
                channelLayout: .init(layoutTag: kAudioChannelLayoutTag_Mono)!
            )
            channelMixerDef.gain = distance.audioGain
            
            let pipeline = PHASESpatialPipeline(flags: [.directPathTransmission])!
            pipeline.entries[.directPathTransmission]!.sendLevel = distance.audioGain
            
            let spatialMixerDef = PHASESpatialMixerDefinition(
                spatialPipeline: pipeline
            )
            
            // Set distance model
            let distanceModel = PHASEGeometricSpreadingDistanceModelParameters()
            distanceModel.fadeOutParameters = PHASEDistanceModelFadeOutParameters(
                cullDistance: 10.0
            )
            spatialMixerDef.distanceModelParameters = distanceModel
            
            // Check if the sound asset was registered
            if let _ = try? engine.assetRegistry.registerSoundAsset(
                url: Bundle.main.url(forResource: soundName, withExtension: "caf")!,
                identifier: "\(soundName)_\(UUID().uuidString)",
                assetType: .resident,
                channelLayout: nil,
                normalizationMode: .dynamic
            ) {
                // Asset registered — create sampler node
                let samplerNode = PHASESamplerNodeDefinition(
                    soundAssetIdentifier: soundName,
                    mixerDefinition: spatialMixerDef
                )
                samplerNode.playbackMode = .oneShot
                samplerNode.rate = distance.audioPitch
                
                try engine.assetRegistry.registerSoundEventAsset(
                    rootNode: samplerNode,
                    identifier: "event_\(soundName)"
                )
                
                let event = try PHASESoundEvent(
                    engine: engine,
                    assetIdentifier: "event_\(soundName)",
                    mixerParameters: [
                        "spatialMixer": PHASEMixerParameters()
                    ]
                )
                
                event.start()
                currentSoundEvent = event
            }
        } catch {
            // If PHASE event creation fails, fallback silently
            print("[SpatialAudio] PHASE playback error: \(error)")
        }
    }
    
    /// Reproduce audio espacial usando AVAudioEngine como fallback.
    private func playSpatialAudioFallback(azimuth: Float, distance: DistanceCategory) {
        guard let playerNode = avPlayerNode else { return }
        
        // Position the player node in 3D space
        let radians = azimuth * .pi / 180.0
        let distanceValue: Float = {
            switch distance {
            case .near:   return 1.0
            case .medium: return 3.0
            case .far:    return 6.0
            }
        }()
        
        playerNode.position = AVAudio3DPoint(
            x: sin(radians) * distanceValue,
            y: 0,
            z: -cos(radians) * distanceValue
        )
        
        // Set volume based on distance
        playerNode.volume = Float(distance.audioGain)
        
        // Generate a simple tone if no sound file is available
        let soundName: String
        switch distance {
        case .near:   soundName = "sonar_near"
        case .medium: soundName = "sonar_medium"
        case .far:    soundName = "sonar_far"
        }
        
        if let url = Bundle.main.url(forResource: soundName, withExtension: "caf"),
           let file = try? AVAudioFile(forReading: url) {
            playerNode.scheduleFile(file, at: nil)
            playerNode.play()
        } else {
            // Generate programmatic beep tone
            playProgrammaticTone(
                frequency: distance == .near ? 880 : (distance == .medium ? 660 : 440),
                duration: 0.15,
                gain: distance.audioGain
            )
        }
    }
    
    /// Genera un tono programático como fallback cuando no hay archivos de sonido.
    private func playProgrammaticTone(frequency: Double, duration: Double, gain: Double) {
        guard let engine = avAudioEngine, let playerNode = avPlayerNode else { return }
        
        let sampleRate: Double = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        
        buffer.frameLength = frameCount
        
        if let floatData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let sample = Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate))
                // Apply envelope to avoid clicks
                let envelope: Float
                let attackSamples = Int(sampleRate * 0.01)
                let releaseSamples = Int(sampleRate * 0.02)
                if i < attackSamples {
                    envelope = Float(i) / Float(attackSamples)
                } else if i > Int(frameCount) - releaseSamples {
                    envelope = Float(Int(frameCount) - i) / Float(releaseSamples)
                } else {
                    envelope = 1.0
                }
                floatData[i] = sample * Float(gain) * envelope * 0.3
            }
        }
        
        playerNode.scheduleBuffer(buffer, at: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    // MARK: - Azimuth Calculation
    
    /// Calcula el ángulo azimut a partir de la posición horizontal normalizada.
    ///
    /// - Parameter normalizedX: Posición X normalizada (0.0–1.0) del centro del objeto.
    /// - Returns: Ángulo azimut en grados (-90° a +90°).
    func calculateAzimuth(from normalizedX: CGFloat) -> Float {
        // Linear interpolation from -90° (left) to +90° (right)
        // 0.0 → -90°, 0.5 → 0°, 1.0 → +90°
        return Float((normalizedX - 0.5) * 2.0) * 90.0
    }
    
    // MARK: - Control
    
    /// Detiene toda reproducción de audio espacial.
    func stop() {
        currentSoundEvent?.stop()
        currentSoundEvent = nil
        
        avPlayerNode?.stop()
        avAudioEngine?.stop()
        
        phaseEngine?.stop()
        
        isActive = false
    }
    
    /// Pausa la reproducción actual.
    func pause() {
        currentSoundEvent?.stop()
        avPlayerNode?.pause()
    }
    
    /// Reanuda la reproducción.
    func resume() {
        avPlayerNode?.play()
    }
    
    /// Actualiza la posición del audio espacial sin cambiar el sonido.
    ///
    /// Útil para actualizaciones suaves de posición mientras el objeto se mueve.
    ///
    /// - Parameters:
    ///   - normalizedX: Posición X normalizada del objeto.
    ///   - distance: Categoría de distancia actual.
    func updatePosition(normalizedX: CGFloat, distance: DistanceCategory) {
        let azimuth = calculateAzimuth(from: normalizedX)
        let radians = azimuth * .pi / 180.0
        let distanceValue: Float = {
            switch distance {
            case .near:   return 1.0
            case .medium: return 3.0
            case .far:    return 6.0
            }
        }()
        
        if !usingFallback, let source = source {
            var transform = matrix_identity_float4x4
            transform.columns.3.x = sin(radians) * distanceValue
            transform.columns.3.z = -cos(radians) * distanceValue
            source.transform = transform
        } else if let playerNode = avPlayerNode {
            playerNode.position = AVAudio3DPoint(
                x: sin(radians) * distanceValue,
                y: 0,
                z: -cos(radians) * distanceValue
            )
            playerNode.volume = Float(distance.audioGain)
        }
    }
}
