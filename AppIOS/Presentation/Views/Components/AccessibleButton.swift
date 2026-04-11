// MARK: - AccessibleButton.swift
// GuideVision — Presentation Layer
// Copyright © 2026 GuideVision. All rights reserved.

import SwiftUI

// MARK: - AccessibleButton

/// Botón accesible diseñado para usuarios con discapacidad visual.
///
/// Características:
/// - Área de toque grande (mínimo 60x60 puntos)
/// - Alto contraste (fondo oscuro, texto blanco)
/// - Feedback háptico al presionar
/// - Integración completa con VoiceOver
/// - Soporte para iconos SF Symbols
struct AccessibleButton: View {
    
    // MARK: - Properties
    
    /// Título del botón.
    let title: String
    
    /// Nombre del ícono SF Symbol.
    let icon: String?
    
    /// Etiqueta de accesibilidad descriptiva.
    let accessibilityDescription: String
    
    /// Pista de accesibilidad.
    let accessibilityHintText: String
    
    /// Acción al presionar.
    let action: () -> Void
    
    /// Estilo del botón.
    var style: AccessibleButtonStyle = .primary
    
    /// Indica si el botón está deshabilitado.
    var isDisabled: Bool = false
    
    // MARK: - Button Styles
    
    enum AccessibleButtonStyle {
        case primary
        case secondary
        case danger
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .gray.opacity(0.3)
            case .danger: return .red
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .danger: return .white
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        title: String,
        icon: String? = nil,
        accessibilityDescription: String? = nil,
        accessibilityHint: String = "",
        style: AccessibleButtonStyle = .primary,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.accessibilityDescription = accessibilityDescription ?? title
        self.accessibilityHintText = accessibilityHint
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(isDisabled ? Color.gray.opacity(0.3) : style.backgroundColor)
            .foregroundColor(isDisabled ? .gray : style.foregroundColor)
            .cornerRadius(16)
        }
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("btn_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        AccessibleButton(
            title: "Buscar Producto",
            icon: "magnifyingglass",
            accessibilityHint: "Activa la búsqueda guiada de un producto"
        ) {
            print("Buscar pressed")
        }
        
        AccessibleButton(
            title: "Leer Etiqueta",
            icon: "doc.text.viewfinder",
            accessibilityHint: "Lee la etiqueta visible frente a la cámara"
        ) {
            print("Leer pressed")
        }
        
        AccessibleButton(
            title: "Cancelar",
            icon: "xmark.circle",
            style: .danger,
            accessibilityHint: "Cancela la operación actual"
        ) {
            print("Cancelar pressed")
        }
    }
    .padding()
}
#endif
