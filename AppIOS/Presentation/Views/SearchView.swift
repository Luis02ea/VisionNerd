//
//  SearchView.swift
//  AppIOS
//
//  Created by Alumno on 10/04/26.
//

// MARK: - SearchView.swift
// GuideVision — Presentation Layer
// Copyright © 2026 GuideVision. All rights reserved.

import SwiftUI

// MARK: - SearchView

/// Vista del flujo de búsqueda guiada con indicadores de progreso.
///
/// Muestra:
/// - Indicador de dirección (izquierda/centro/derecha) con animación
/// - Barra de proximidad progresiva
/// - Indicador de estado de la búsqueda
/// - Botón de cancelación accesible
///
/// ## Accesibilidad
/// Todos los indicadores visuales tienen equivalentes de VoiceOver.
/// La dirección y proximidad se anuncian periódicamente.
struct SearchView: View {
    
    // MARK: - Properties
    
    @State var viewModel: SearchViewModel
    
    /// Acción al cancelar la búsqueda.
    let onCancel: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            // Search query header
            Text("Buscando: \(viewModel.currentQuery)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .accessibilityLabel("Buscando \(viewModel.currentQuery)")
            
            // Direction indicator
            directionIndicator
            
            // Proximity bar
            proximityBar
            
            // Status info
            statusInfo
            
            Spacer()
            
            // Cancel button
            AccessibleButton(
                title: "Cancelar Búsqueda",
                icon: "xmark.circle",
                accessibilityDescription: "Cancelar la búsqueda actual",
                accessibilityHint: "Detiene la búsqueda y vuelve a la pantalla principal",
                style: .danger
            ) {
                onCancel()
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Panel de búsqueda guiada")
    }
    
    // MARK: - Direction Indicator
    
    private var directionIndicator: some View {
        HStack(spacing: 0) {
            ForEach(["Izquierda", "Centro", "Derecha"], id: \.self) { label in
                let isActive = isDirectionActive(label)
                
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 60)
                        .overlay(
                            Image(systemName: directionIcon(for: label))
                                .font(.title)
                                .foregroundColor(isActive ? .white : .gray)
                        )
                        .animation(.easeInOut(duration: 0.3), value: isActive)
                    
                    Text(label)
                        .font(.caption)
                        .foregroundColor(isActive ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(label): \(isActive ? "activo" : "inactivo")")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dirección: \(viewModel.currentDirection?.localizedDescription ?? "desconocida")")
    }
    
    // MARK: - Proximity Bar
    
    private var proximityBar: some View {
        VStack(spacing: 8) {
            Text("Proximidad")
                .font(.headline)
                .foregroundColor(.white)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 12)
                        .fill(proximityGradient)
                        .frame(width: geometry.size.width * viewModel.proximityProgress)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.proximityProgress)
                }
            }
            .frame(height: 30)
            
            // Distance label
            Text(viewModel.currentDistance?.localizedDescription ?? "Calculando distancia...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Proximidad: \(Int(viewModel.proximityProgress * 100)) por ciento. \(viewModel.currentDistance?.localizedDescription ?? "")")
    }
    
    // MARK: - Status Info
    
    private var statusInfo: some View {
        HStack {
            Label("\(viewModel.framesProcessed) frames", systemImage: "camera.viewfinder")
            Spacer()
            Label(formatTime(viewModel.elapsedTime), systemImage: "clock")
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.6))
        .accessibilityHidden(true)
    }
    
    // MARK: - Helpers
    
    private func isDirectionActive(_ label: String) -> Bool {
        switch (label, viewModel.currentDirection) {
        case ("Izquierda", .left): return true
        case ("Centro", .center): return true
        case ("Derecha", .right): return true
        default: return false
        }
    }
    
    private func directionIcon(for label: String) -> String {
        switch label {
        case "Izquierda": return "arrow.left"
        case "Centro": return "arrow.up"
        case "Derecha": return "arrow.right"
        default: return "arrow.up"
        }
    }
    
    private var proximityGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .green, .yellow, .orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
