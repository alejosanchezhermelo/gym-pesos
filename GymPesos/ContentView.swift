import SwiftUI

struct ContentView: View {
    /// Inicio del entrenamiento en segundos desde 1970; 0 = no hay entrenamiento.
    @AppStorage("workoutStart") private var workoutStart: Double = 0
    @AppStorage("lastDuration") private var lastDuration: Double = 0
    @State private var confirmingEnd = false
    @State private var confirmResetTask: Task<Void, Never>?

    private var startDate: Date? {
        workoutStart > 0 ? Date(timeIntervalSince1970: workoutStart) : nil
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer()
                clock
                Spacer()
                controls
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: workoutStart)
        .animation(.easeOut(duration: 0.2), value: confirmingEnd)
        .task { await LiveActivityManager.sync(startDate: startDate) }
    }

    // MARK: - Partes

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ENTRENAMIENTO")
                .font(.display(13, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(Palette.muted)
            (Text("PESOS DEL ").foregroundColor(Palette.fg) + Text("GYM").foregroundColor(Palette.accent))
                .font(.display(40, weight: .heavy))
        }
    }

    private var clock: some View {
        VStack(spacing: 10) {
            if let startDate {
                HStack(spacing: 6) {
                    BlinkingDot()
                    Text("ENTRENANDO")
                        .font(.display(14, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Palette.muted)
                }
                TimelineView(.periodic(from: startDate, by: 1)) { context in
                    Text(formatElapsed(context.date.timeIntervalSince(startDate)))
                        .font(.display(104, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
            } else {
                Text("LISTO PARA ENTRENAR")
                    .font(.display(14, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Palette.muted)
                Text("0:00")
                    .font(.display(104, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.line)
                if lastDuration > 0 {
                    Text("Último entrenamiento: \(formatElapsed(lastDuration))")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controls: some View {
        if startDate == nil {
            SlideToStart(label: "Deslizá para arrancar") { start() }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Button(action: endTapped) {
                Text(confirmingEnd ? "¿Terminar?" : "Terminar")
                    .font(.display(22, weight: .bold))
                    .tracking(0.9)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .foregroundStyle(confirmingEnd ? Palette.accentInk : Palette.fg)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(confirmingEnd ? Palette.warn : Palette.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(confirmingEnd ? Palette.warn : Palette.line, lineWidth: 1)
                    )
            }
            .buttonStyle(PressScale())
            .sensoryFeedback(.warning, trigger: confirmingEnd) { _, new in new }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Acciones

    private func start() {
        let now = Date()
        workoutStart = now.timeIntervalSince1970
        LiveActivityManager.start(at: now)
    }

    private func endTapped() {
        guard confirmingEnd else {
            confirmingEnd = true
            confirmResetTask?.cancel()
            confirmResetTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { confirmingEnd = false }
            }
            return
        }
        confirmResetTask?.cancel()
        confirmingEnd = false
        if let startDate { lastDuration = Date().timeIntervalSince(startDate) }
        workoutStart = 0
        Task { await LiveActivityManager.endAll() }
    }
}

func formatElapsed(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

// MARK: - Componentes

/// Control "Deslizá para arrancar": se arrastra la perilla hasta el final.
struct SlideToStart: View {
    let label: String
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var completed = false
    @State private var shimmer = false

    private let height: CGFloat = 68
    private let knob: CGFloat = 58

    private var labelText: some View {
        Text(label)
            .font(.display(20, weight: .bold))
            .tracking(1.2)
            .textCase(.uppercase)
            .lineLimit(1)
    }

    var body: some View {
        GeometryReader { geo in
            let maxOffset = geo.size.width - knob - 10
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surface2)
                Capsule().stroke(Palette.line, lineWidth: 1)

                Capsule()
                    .fill(Palette.accent.opacity(0.12))
                    .frame(width: offset + knob + 10)

                labelText
                    .foregroundStyle(Palette.muted)
                    .overlay {
                        // Brillo que recorre el texto, como en la maqueta.
                        GeometryReader { g in
                            LinearGradient(
                                colors: [.clear, Palette.fg, .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: g.size.width * 0.4)
                            .offset(x: shimmer ? g.size.width : -g.size.width * 0.4)
                        }
                        .mask(labelText)
                    }
                    .opacity(1 - Double(offset / max(maxOffset, 1)) * 1.3)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, knob)

                Circle()
                    .fill(Palette.accent)
                    .frame(width: knob, height: knob)
                    .overlay(
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(Palette.accentInk)
                    )
                    .offset(x: 5 + offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !completed else { return }
                                offset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                guard !completed else { return }
                                if offset > maxOffset * 0.85 {
                                    completed = true
                                    withAnimation(.easeOut(duration: 0.15)) { offset = maxOffset }
                                    onComplete()
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = 0 }
                                }
                            }
                    )
                    .accessibilityLabel("Arrancar entrenamiento")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { completed = true; onComplete() }
            }
        }
        .frame(height: height)
        .sensoryFeedback(.success, trigger: completed) { _, new in new }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { shimmer = true }
        }
    }
}

struct BlinkingDot: View {
    @State private var dim = false
    var body: some View {
        Circle()
            .fill(Palette.accent)
            .frame(width: 8, height: 8)
            .opacity(dim ? 0.25 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) { dim = true }
            }
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
