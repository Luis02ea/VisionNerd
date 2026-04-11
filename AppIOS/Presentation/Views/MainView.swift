// MARK: - MainView.swift
import SwiftUI
import Foundation
import CoreGraphics
import Combine

// MARK: - Design Tokens

private enum GVColor {
    static let bgPage     = Color(hex: "#0C0C0E")
    static let bgSurface  = Color(hex: "#141417")
    static let bgElevated = Color(hex: "#1C1C21")
    static let bgCard     = Color(hex: "#222228")

    static let accent     = Color(hex: "#E8C547")
    static let accentDim  = Color(hex: "#9A8230")
    static let accentGlow = Color(hex: "#E8C547").opacity(0.12)

    static let success    = Color(hex: "#47E8A0")
    static let info       = Color(hex: "#47A0E8")
    static let danger     = Color(hex: "#E85547")

    static let textPrimary   = Color(hex: "#F2F2F0")
    static let textSecondary = Color(hex: "#8A8A94")
    static let textMuted     = Color(hex: "#50505A")

    static let border        = Color.white.opacity(0.07)
    static let borderAccent  = Color(hex: "#E8C547").opacity(0.30)
}

private enum GVFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Syne", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("DM Mono", size: size).weight(weight)
    }
}

// MARK: - MainView

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

            // MARK: 1 — Camera feed background
            CameraPreviewView(
                session: cameraService.captureSession,
                detectedObjects: viewModel.detectedObjects
            )
            .ignoresSafeArea()

            // MARK: 2 — Camera grid overlay (visual reference)
            CameraGridOverlay(state: viewModel.searchState)
                .ignoresSafeArea()

            // MARK: 3 — Gradient vignettes top + bottom
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

            // MARK: 4 — Main layout
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

    // MARK: - Status Bar
    // Matches: statusBar computed property
    // Top row: brand name / status dot + text / settings icon

    private var statusBar: some View {
        HStack(alignment: .center, spacing: 0) {

            // Brand
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(GVColor.accent)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "eye.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(GVColor.bgPage)
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

            // Status pill
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

            // Settings
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

    // MARK: - Search Status View
    // Matches: searchStatusView computed property
    // Center area — visible only when searchState != .idle

    private var searchStatusView: some View {
        VStack(spacing: 12) {

            // Spatial audio position bar
            SpatialAudioBar(position: viewModel.spatialPosition)

            // Direction card (only in .guiding state)
            if case .guiding(let direction) = viewModel.searchState {
                DirectionCard(direction: direction)
            }

            // Recognized text bubble
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

            // Processing spinner
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

            // Detected objects panel
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

    // MARK: - Control Panel
    // Matches: controlPanel computed property
    // Bottom area: main voice button + quick actions + last spoken text

    private var controlPanel: some View {
        VStack(spacing: 10) {

            // Last spoken text
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

            // Quick action row: Describir + Leer
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

            // Main voice button
            MainVoiceButton(
                title: mainButtonTitle,
                icon: mainButtonIcon,
                state: viewModel.searchState,
                accessibilityDescription: mainButtonAccessibilityLabel
            ) {
                viewModel.activateVoiceInput()
            }
            .padding(.horizontal, 20)

            // Home indicator space
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 120, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch viewModel.searchState {
        case .idle:             return GVColor.success
        case .listening:        return GVColor.orange
        case .scanning:         return GVColor.info
        case .guiding:          return GVColor.accent
        case .found:            return GVColor.success
        case .error:            return GVColor.danger
        default:                return GVColor.accent
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
        case .idle:             return "Activar voz"
        case .listening:        return "Escuchando…"
        case .scanning, .guiding: return "Cancelar búsqueda"
        default:                return "Activar voz"
        }
    }

    private var mainButtonIcon: String {
        switch viewModel.searchState {
        case .idle:             return "mic.fill"
        case .listening:        return "waveform"
        case .scanning, .guiding: return "xmark.circle.fill"
        default:                return "mic.fill"
        }
    }

    private var mainButtonAccessibilityLabel: String {
        switch viewModel.searchState {
        case .idle:             return "Activar comando de voz"
        case .listening:        return "Escuchando. Habla ahora."
        case .scanning, .guiding: return "Cancelar búsqueda activa"
        default:                return "Activar comando de voz"
        }
    }
}

// MARK: - MainVoiceButton
// Botón principal de acción — estilo: filled accent en idle,
// outlined naranja en listening, rojo suave en scanning/guiding

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
        default:                return GVColor.bgPage
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

// MARK: - QuickActionButton
// Botones secundarios: Describir / Leer

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
                    .foregroundColor(GVColor.textSecondary)

                Text(title)
                    .font(GVFont.mono(10, weight: .medium))
                    .foregroundColor(GVColor.textMuted)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(GVColor.bgCard)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GVColor.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel(description)
        .accessibilityHint(hint)
    }
}

// MARK: - SpatialAudioBar
// Indicador de posición izquierda–derecha del objeto detectado.
// position: 0.0 = izquierda total, 1.0 = derecha total, 0.5 = centro

private struct SpatialAudioBar: View {
    let position: Double // 0.0 ... 1.0

    var body: some View {
        HStack(spacing: 8) {
            Text("L")
                .font(GVFont.mono(9))
                .foregroundColor(GVColor.textMuted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
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

// MARK: - DirectionCard
// Tarjeta con flecha de dirección — visible en estado .guiding

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
                        .foregroundColor(GVColor.bgPage)
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

// MARK: - DetectedObjectsPanel
// Panel de objetos detectados — aparece en scanning/guiding

private struct DetectedObjectsPanel: View {
    let objects: [DetectedObject]
    let targetLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Heading
            HStack {
               // ❌ Línea problemática
Text(targetLabel != nil ? "Buscando: "\(targetLabel!)"" : "Objetos detectados")
                    .font(GVFont.mono(9, weight: .medium))
                    .foregroundColor(GVColor.textMuted)
                    .kerning(0.8)
                    .textCase(.uppercase)

                Spacer()

                Text("\(objects.count) obj.")
                    .font(GVFont.mono(9))
                    .foregroundColor(GVColor.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
                .background(GVColor.border)

            // Object rows
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

// MARK: - CameraGridOverlay
// Rejilla sobre el viewfinder para referencia visual — cambia de color según estado

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

// MARK: - Color(hex:) extension

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

// MARK: - Color orange convenience

extension GVColor {
    static let orange = Color(hex: "#E8924A")
}

// MARK: - Preview

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
            direction: GuideDirection(
                side: .right,
                instruction: "Gira ligeramente a la derecha",
                detail: "Cereal · ~1.8m · confianza 94%"
            )
        )),
        cameraService: CameraService.preview()
    )
}

#Preview("Found + OCR") {
    MainView(
        viewModel: MainViewModel.preview(state: .found),
        cameraService: CameraService.preview()
    )
}
#endif
