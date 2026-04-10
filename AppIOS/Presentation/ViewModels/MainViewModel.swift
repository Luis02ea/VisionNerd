//
//  MainViewModel.swift
//  AppIOS
//
//  Created by Alumno on 09/04/26.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor

final class MainViewModel
{
    var busquedaStado: BusquedaStado = .idle
    var detectarObjetos: [DetectarObjeto] = []
    var ultimoTexto: String = ""
    var procesoDeLaSolicitud: Bool = false
    var MensajeDeError: String?
    var estadoDeLaCamara: Bool = false
    var textoReconocido: String = ""
    var labelInfo: LabelInfo?
    
    
    private let detectObjectsUseCase: DetectObjectsUseCase
    private let busquedaProductosUseCase: BusquedaProductosUseCase
    private let readLabelUseCase: ReadLabelUseCase
    private let describeSceneUseCase: DescribeSceneUseCase
    
    private let speechSynthesizer: SpeechSynthesizer
    private let voiceRecognition: VoiceRecognition
    private let spatialAudioEngine: SpatialAudioEngine
    private let hapticEngine: HapticEngine
    private let accessibility: Accessibility
    
    
//MARK:
    
    
    
    
    
}
