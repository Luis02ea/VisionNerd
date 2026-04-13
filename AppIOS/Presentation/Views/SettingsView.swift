//
//  SettingsView.swift
//  AppIOS
//
//  Created by Alumno on 10/04/26.
//

import SwiftUI
import AVFoundation

// MARK: - SettingsView

struct SettingsView: View {
    
    // MARK: - Properties
    
    @State var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: Voice Settings
                Section {
                    VStack(alignment: .leading) {
                        Text("Velocidad de voz: \(Int(viewModel.speechRate * 200))%")
                        Slider(
                            value: $viewModel.speechRate,
                            in: 0.1...1.0,
                            step: 0.05
                        )
                        .accessibilityLabel("Velocidad de voz")
                        .accessibilityValue("\(Int(viewModel.speechRate * 200)) por ciento")
                        .accessibilityHint("Desliza para ajustar la velocidad de la voz")
                    }
                    
                    Picker("Voz", selection: $viewModel.preferredVoice) {
                        ForEach(viewModel.availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))")
                                .tag(voice.identifier)
                        }
                    }
                    .accessibilityLabel("Seleccionar voz")
                    .accessibilityHint("Elige la voz para los anuncios")
                    
                    Button("Probar voz") {
                        viewModel.testVoice()
                    }
                    .accessibilityLabel("Probar la voz seleccionada")
                    .accessibilityHint("Reproduce un mensaje de prueba con la voz actual")
                } header: {
                    Text("Voz")
                        .accessibilityAddTraits(.isHeader)
                }
                
                // MARK: AI Settings
                Section {
                    Toggle("Solo modo local", isOn: $viewModel.localOnlyMode)
                        .accessibilityLabel("Modo solo local")
                        .accessibilityHint("Cuando está activo, no se usan servicios de IA en la nube")
                    
                    if !viewModel.localOnlyMode {
                        Picker("Proveedor de IA", selection: $viewModel.selectedProvider) {
                            Text("OpenAI").tag("openai")
                            Text("Anthropic (Claude)").tag("anthropic")
                        }
                        .accessibilityLabel("Proveedor de inteligencia artificial")
                        
                        SecureField("API Key de OpenAI", text: $viewModel.openAIKey)
                            .accessibilityLabel("Clave API de OpenAI")
                            .accessibilityHint("Ingresa tu clave API de OpenAI para descripción de escenas")
                            .textContentType(.password)
                        
                        SecureField("API Key de Anthropic", text: $viewModel.anthropicKey)
                            .accessibilityLabel("Clave API de Anthropic")
                            .accessibilityHint("Ingresa tu clave API de Anthropic para descripción de escenas")
                            .textContentType(.password)
                    }
                } header: {
                    Text("Inteligencia Artificial")
                        .accessibilityAddTraits(.isHeader)
                }
                
                // MARK: About
                Section {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Versión 1.0.0")
                    
                    Button("Restablecer ajustes") {
                        viewModel.resetToDefaults()
                    }
                    .foregroundColor(.red)
                    .accessibilityLabel("Restablecer todos los ajustes a valores predeterminados")
                    .accessibilityHint("Esta acción no se puede deshacer")
                } header: {
                    Text("Acerca de")
                        .accessibilityAddTraits(.isHeader)
                }
                
                // MARK: Help
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        helpItem(command: "\"Buscar [producto]\"", description: "Inicia búsqueda guiada")
                        helpItem(command: "\"¿Qué hay delante?\"", description: "Describe la escena")
                        helpItem(command: "\"Leer etiqueta\"", description: "Lee texto con OCR")
                        helpItem(command: "\"¿A qué distancia?\"", description: "Distancia al objeto más cercano")
                        helpItem(command: "\"Cancelar\"", description: "Cancela la operación activa")
                    }
                } header: {
                    Text("Comandos de voz")
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .accessibilityLabel("Cerrar ajustes")
                    .accessibilityHint("Vuelve a la pantalla principal")
                }
            }
        }
    }
    
    // MARK: - Help Item
    
    private func helpItem(command: String, description: String) -> some View {
        HStack {
            Text(command)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            Spacer()
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Comando: \(command). \(description)")
    }
}
