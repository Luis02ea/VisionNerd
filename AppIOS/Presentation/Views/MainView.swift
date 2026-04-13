import SwiftUI
import Foundation
import CoreGraphics
import Combine

private enum GVColor {
    static let bgPage     = Color(hex: "#F5F5DC")
    static let bgSurface  = Color(hex: "#EEEEDD")
    static let bgElevated = Color(hex: "#E8E8D0")
    static let bgCard     = Color(hex: "#DDDDC8")

    static let accent     = Color(hex: "#F8DF54")
    static let accentDim  = Color(hex: "#9A8230")
    static let accentGlow = Color(hex: "#F8DF54").opacity(0.12)

    static let success    = Color(hex: "#47E8A0")
    static let info       = Color(hex: "#47A0E8")
    static let danger     = Color(hex: "#E85547")

    static let textPrimary   = Color(hex: "#1A1A1A")
    static let textSecondary = Color(hex: "#4A4A4A")
    static let textMuted     = Color(hex: "#6A6A6A")

    static let border        = Color.black.opacity(0.15)
    static let borderAccent  = Color(hex: "#F8DF54").opacity(0.50)
}

private enum GVFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Syne", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("DM Mono", size: size).weight(weight)
    }
}

struct MainView: View {

    @State private var viewModel: MainViewModel
    @State private var showSettings = false

    let cameraService: CameraService

    init(viewModel: MainViewModel, cameraService: CameraService) {
        self._viewModel = State(wrappedValue: viewModel)
        self.cameraService = cameraService
    }

    var body: some View {
        ZStack {

            CameraPreviewView(
                session: cameraService.captureSession,
                detectedObjects: viewModel.detectedObjects
            )
            .ignoresSafeArea()

            CameraGridOverlay(state: viewModel.searchState)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [GVColor.bgPage.opacity(0.85), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 140)

                Spacer()

                LinearGradient(
                    colors: [.clear, GVColor.bgPage.opacity(0.92)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                Spacer()
                if viewModel.searchState != .idle {
                    searchStatusView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Spacer()
                controlPanel
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.searchState)
        }
        .background(GVColor.bgPage)
        .onAppear  { viewModel.onAppear()  }
        .onDisappear { viewModel.onDisappear() }
        .onTapGesture(count: 2) { viewModel.activateVoiceInput() }
        .guideVisionCustomActions(
            onSearch:    { viewModel.activateVoiceInput() },
            onDescribe:  { viewModel.handleIntent(.describeScene) },
            onReadLabel: { viewModel.handleIntent(.readLabel) }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GuideVision — Pantalla principal")
        .accessibilityHint("Toca dos veces para activar el comando de voz.")
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: SettingsViewModel())
        }
    }

    private var statusBar: some View {
        HStack(alignment: .center, spacing: 0) {

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#9FD2D6"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image("Start")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("GuideVision")
                        .font(GVFont.display(18, weight: .heavy))
                        .foregroundColor(GVColor.textPrimary)

                    Text("iOS · Swift 5.9+")
                        .font(GVFont.mono(9))
                        .foregroundColor(GVColor.textMuted)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)

                Text(statusText.uppercased())
                    .font(GVFont.mono(10, weight: .medium))
                    .foregroundColor(GVColor.textSecondary)
                    .kerning(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(GVColor.bgCard)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(GVColor.border, lineWidth: 0.5)
            )
            .clipShape(Capsule())

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(GVColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(GVColor.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GVColor.border, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.leading, 10)
            .accessibilityLabel("Ajustes")
            .accessibilityHint("Abre la pantalla de configuración")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var searchStatusView: some View {
        VStack(spacing: 12) {

            SpatialAudioBar(position: viewModel.spatialPosition)

            if case .guiding(_, let lastObject) = viewModel.searchState,
               let object = lastObject {
                DirectionCard(direction: GuideDirection.from(object: object))
            }

            if !viewModel.recognizedText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                        .foregroundColor(GVColor.accent)

                    Text(viewModel.recognizedText)
                        .font(GVFont.display(13, weight: .medium))
                        .foregroundColor(GVColor.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(GVColor.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GVColor.borderAccent, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(GVColor.accent)
                        .scaleEffect(0.8)

                    Text("Procesando…")
                        .font(GVFont.mono(11))
                        .foregroundColor(GVColor.textMuted)
                }
            }

            if !viewModel.detectedObjects.isEmpty {
                DetectedObjectsPanel(
                    objects: viewModel.detectedObjects,
                    targetLabel: viewModel.currentSearchQuery
                )
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado de búsqueda: \(viewModel.searchState.name)")
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {

            if !viewModel.lastSpokenText.isEmpty {
                Text(viewModel.lastSpokenText)
                    .font(GVFont.mono(11))
                    .foregroundColor(GVColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(GVColor.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GVColor.border, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Último mensaje: \(viewModel.lastSpokenText)")
            }

            HStack(spacing: 10) {
                QuickActionButton(
                    title: "Describir",
                    systemIcon: "eye",
                    description: "Describir escena",
                    hint: "Describe lo que la cámara está viendo"
                ) {
                    viewModel.handleIntent(.describeScene)
                }

                QuickActionButton(
                    title: "Leer",
                    systemIcon: "doc.text.viewfinder",
                    description: "Leer etiqueta",
                    hint: "Lee la etiqueta visible frente a la cámara"
                ) {
                    viewModel.handleIntent(.readLabel)
                }
            }
            .padding(.horizontal, 20)

            MainVoiceButton(
                title: mainButtonTitle,
                icon: mainButtonIcon,
                state: viewModel.searchState,
                accessibilityDescription: mainButtonAccessibilityLabel
            ) {
                viewModel.activateVoiceInput()
            }
            .padding(.horizontal, 20)

            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 120, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .padding(.bottom, 16)
    }

    private var statusColor: Color {
        switch viewModel.searchState {
        case .idle:             return GVColor.success
        case .listening:        return GVColor.orange
        case .scanning:         return GVColor.info
        case .guiding:          return GVColor.accent
        case .found:            return GVColor.success
        case .error:            return GVColor.danger
        case .processing:       return GVColor.accent
        }
    }

    private var statusText: String {
        switch viewModel.searchState {
        case .idle:             return "Listo"
        case .listening:        return "Escuchando"
        case .processing:       return "Procesando"
        case .scanning:         return "Buscando"
        case .guiding:          return "Guiando"
        case .found:            return "¡Encontrado!"
        case .error:            return "Error"
        }
    }

    private var mainButtonTitle: String {
        switch viewModel.searchState {
        case .idle:                  return "Activar voz"
        case .listening:             return "Escuchando…"
        case .scanning, .guiding:    return "Cancelar búsqueda"
        case .processing:            return "Procesando…"
        case .found:                 return "Activar voz"
        case .error:                 return "Activar voz"
        }
    }

    private var mainButtonIcon: String {
        switch viewModel.searchState {
        case .idle:                  return "mic.fill"
        case .listening:             return "waveform"
        case .scanning, .guiding:    return "xmark.circle.fill"
        case .processing:            return "hourglass"
        case .found:                 return "mic.fill"
        case .error:                 return "mic.fill"
        }
    }

    private var mainButtonAccessibilityLabel: String {
        switch viewModel.searchState {
        case .idle:                  return "Activar comando de voz"
        case .listening:             return "Escuchando. Habla ahora."
        case .scanning, .guiding:    return "Cancelar búsqueda activa"
        case .processing:            return "Procesando solicitud"
        case .found:                 return "Activar comando de voz"
        case .error:                 return "Activar comando de voz"
        }
    }
}

private struct MainVoiceButton: View {
    let title: String
    let icon: String
    let state: SearchState
    let accessibilityDescription: String
    let action: () -> Void

    private var bgColor: Color {
        switch state {
        case .listening:        return Color(hex: "#E8924A")
        case .scanning, .guiding: return Color(hex: "#2A1A1A")
        default:                return GVColor.accent
        }
    }

    private var fgColor: Color {
        switch state {
        case .scanning, .guiding: return GVColor.danger
        case .listening:        return .white
        default:                return Color(hex: "#1A1A1A")
        }
    }

    private var borderColor: Color {
        switch state {
        case .scanning, .guiding: return GVColor.danger.opacity(0.4)
        case .listening:        return Color(hex: "#E8924A").opacity(0.5)
        default:                return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))

                Text(title)
                    .font(GVFont.display(16, weight: .bold))
            }
            .foregroundColor(fgColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Activa el reconocimiento de voz para dar un comando")
        .accessibilityAddTraits(.isButton)
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemIcon: String
    let description: String
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "#0C0C0E"))

                Text(title)
                    .font(GVFont.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#0C0C0E"))
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color(hex: "#9FD2D6"))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "#9FD2D6").opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel(description)
        .accessibilityHint(hint)
    }
}

private struct SpatialAudioBar: View {
    let position: Double

    var body: some View {
        HStack(spacing: 8) {
            Text("L")
                .font(GVFont.mono(9))
                .foregroundColor(GVColor.textMuted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 3)

                    Circle()
                        .fill(GVColor.accent)
                        .frame(width: 12, height: 12)
                        .shadow(color: GVColor.accent.opacity(0.5), radius: 4)
                        .offset(x: geo.size.width * position - 6)
                }
            }
            .frame(height: 12)

            Text("R")
                .font(GVFont.mono(9))
                .foregroundColor(GVColor.textMuted)
        }
        .padding(.horizontal, 20)
        .accessibilityLabel("Audio espacial: \(position < 0.4 ? "izquierda" : position > 0.6 ? "derecha" : "centro")")
        .accessibilityHidden(false)
    }
}

private struct DirectionCard: View {
    let direction: GuideDirection

    private var arrowIcon: String {
        switch direction.side {
        case .left:   return "arrow.left"
        case .right:  return "arrow.right"
        case .center: return "arrow.up"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(GVColor.accent)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: arrowIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(direction.instruction)
                    .font(GVFont.display(13, weight: .semibold))
                    .foregroundColor(GVColor.textPrimary)

                Text(direction.detail)
                    .font(GVFont.mono(10))
                    .foregroundColor(GVColor.accentDim)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(GVColor.accentGlow)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GVColor.borderAccent, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(direction.instruction). \(direction.detail)")
    }
}

private struct DetectedObjectsPanel: View {
    let objects: [DetectedObject]
    let targetLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let target = targetLabel {
                    Text("Buscando: \(target)")
                        .font(GVFont.mono(9, weight: .medium))
                        .foregroundColor(GVColor.textMuted)
                        .kerning(0.8)
                        .textCase(.uppercase)
                } else {
                    Text("Objetos detectados")
                        .font(GVFont.mono(9, weight: .medium))
                        .foregroundColor(GVColor.textMuted)
                        .kerning(0.8)
                        .textCase(.uppercase)
                }

                Spacer()

                Text("\(objects.count) obj.")
                    .font(GVFont.mono(9))
                    .foregroundColor(GVColor.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
                .background(GVColor.border)

            ForEach(Array(objects.prefix(3).enumerated()), id: \.offset) { idx, obj in
                let isTarget = obj.label.lowercased() == targetLabel?.lowercased()

                HStack(spacing: 10) {
                    Circle()
                        .fill(isTarget ? GVColor.accent : GVColor.textMuted.opacity(0.4))
                        .frame(width: 6, height: 6)

                    Text(obj.label)
                        .font(GVFont.display(12, weight: isTarget ? .semibold : .regular))
                        .foregroundColor(isTarget ? GVColor.accent : GVColor.textPrimary)

                    if isTarget {
                        Text("← objetivo")
                            .font(GVFont.mono(9))
                            .foregroundColor(GVColor.accentDim)
                    }

                    Spacer()

                    Text(obj.distanceLabel)
                        .font(GVFont.mono(10))
                        .foregroundColor(isTarget ? GVColor.accentDim : GVColor.textSecondary)

                    Text(String(format: "%.0f%%", obj.confidence * 100))
                        .font(GVFont.mono(9))
                        .foregroundColor(GVColor.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(GVColor.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isTarget ? GVColor.accentGlow : .clear)

                if idx < min(objects.count, 3) - 1 {
                    Divider()
                        .background(GVColor.border)
                        .padding(.leading, 28)
                }
            }
        }
        .background(GVColor.bgCard.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GVColor.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }
}

private struct CameraGridOverlay: View {
    let state: SearchState

    private var lineColor: Color {
        switch state {
        case .scanning, .guiding: return GVColor.accent.opacity(0.04)
        case .found:              return GVColor.success.opacity(0.04)
        default:                  return Color.white.opacity(0.03)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cols = 8
            let rows = 14
            let cw = geo.size.width / CGFloat(cols)
            let rh = geo.size.height / CGFloat(rows)

            Canvas { ctx, size in
                var path = Path()
                for c in 1..<cols {
                    let x = cw * CGFloat(c)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for r in 1..<rows {
                    let y = rh * CGFloat(r)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension GVColor {
    static let orange = Color(hex: "#E8924A")
}

#if DEBUG
#Preview("Idle") {
    MainView(
        viewModel: MainViewModel.preview(state: .idle),
        cameraService: CameraService.preview()
    )
}

#Preview("Guiding") {
    MainView(
        viewModel: MainViewModel.preview(state: .guiding(
            query: "Cereal",
            lastObject: DetectedObject(
                label: "Cereal",
                boundingBox: CGRect(x: 0.6, y: 0.3, width: 0.2, height: 0.25),
                confidence: 0.94
            )
        )),
        cameraService: CameraService.preview()
    )
}

#Preview("Found + OCR") {
    MainView(
        viewModel: MainViewModel.preview(state: .found(
            object: DetectedObject(
                label: "Leche",
                boundingBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.5),
                confidence: 0.97
            )
        )),
        cameraService: CameraService.preview()
    )
}
#endif
