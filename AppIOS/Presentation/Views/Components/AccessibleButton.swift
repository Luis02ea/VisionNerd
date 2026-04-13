import SwiftUI

struct AccessibleButton: View {
    
    let title: String
    
    let icon: String?
    
    let accessibilityDescription: String
    
    let accessibilityHintText: String
    
    let action: () -> Void
    
    var style: AccessibleButtonStyle = .primary
    
    var isDisabled: Bool = false
    
    enum AccessibleButtonStyle {
        case primary
        case secondary
        case danger
        
        
        var backgroundColor: Color {
            switch self {
            case .primary: return Color(red: 18/255, green: 186/255, blue: 170/255)
            case .secondary: return Color(red: 159/255, green: 210/255, blue: 214/255)
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

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 159/255, green: 210/255, blue: 214/255))
                .frame(width: 36, height: 36)
                .overlay(
                    Image("Start")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                )
            
            Text("BrightEyes")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(Color(red: 26/255, green: 26/255, blue: 26/255))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color(red: 245/255, green: 245/255, blue: 220/255))
        
        Spacer()
        
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
                accessibilityHint: "Lee la etiqueta visible frente a la cámara",
                style: .secondary
            ) {
                print("Leer pressed")
            }
            
            AccessibleButton(
                title: "Cancelar",
                icon: "xmark.circle",
                accessibilityHint: "Cancela la operación actual", style: .danger
            ) {
                print("Cancelar pressed")
            }
        }
        .padding()
        
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 245/255, green: 245/255, blue: 220/255))
}
#endif
