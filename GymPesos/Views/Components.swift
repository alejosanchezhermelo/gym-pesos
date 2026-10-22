import Charts
import SwiftUI

extension View {
    /// Rótulo chico en mayúsculas (`.eyebrow` de la maqueta).
    func eyebrow(_ size: CGFloat = 13) -> some View {
        font(.display(size, weight: .semibold))
            .tracking(size * 0.14)
            .textCase(.uppercase)
            .foregroundStyle(Palette.muted)
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Barra de abajo, al alcance del pulgar.
struct Dock<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) { content }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(alignment: .top) {
                LinearGradient(
                    colors: [Palette.bg.opacity(0), Palette.bg],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.3)
                )
                .ignoresSafeArea(edges: .bottom)
            }
    }
}

struct BigButton: View {
    enum Kind { case primary, secondary }

    let title: String
    var systemImage: String? = nil
    var kind: Kind = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.display(20, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(kind == .primary ? Palette.accentInk : Palette.fg)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 16).fill(kind == .primary ? Palette.accent : Palette.surface2))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(kind == .primary ? Palette.accent : Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }
}

struct DockIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Palette.fg)
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface2))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
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

/// Control "Deslizá para arrancar": se arrastra la perilla hasta el final.
struct SlideToStart: View {
    let label: String
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var completed = false
    @State private var shimmer = false

    private let height: CGFloat = 64
    private let knob: CGFloat = 54

    private var labelText: some View {
        Text(label)
            .font(.display(19, weight: .bold))
            .tracking(1.1)
            .textCase(.uppercase)
            .lineLimit(1)
    }

    var body: some View {
        GeometryReader { geo in
            let maxOffset = max(1, geo.size.width - knob - 10)
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
                            LinearGradient(colors: [.clear, Palette.fg, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: g.size.width * 0.4)
                                .offset(x: shimmer ? g.size.width : -g.size.width * 0.4)
                        }
                        .mask(labelText)
                    }
                    .opacity(max(0, 1 - Double(offset / maxOffset) * 1.4))
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
                    .accessibilityAction {
                        completed = true
                        onComplete()
                    }
            }
        }
        .frame(height: height)
        .sensoryFeedback(.success, trigger: completed) { _, new in new }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { shimmer = true }
        }
    }
}

/// Cronómetro del dock con "Terminar" que pide un segundo toque.
struct RunPanel: View {
    let start: Date
    let onEnd: () -> Void

    @State private var confirming = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    BlinkingDot()
                    Text("Entrenando").eyebrow(12)
                }
                TimelineView(.periodic(from: start, by: 1)) { ctx in
                    Text(formatElapsed(ctx.date.timeIntervalSince(start)))
                        .font(.display(40, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 4)
            Button(action: tap) {
                Text(confirming ? "¿Terminar?" : "Terminar")
                    .font(.display(18, weight: .bold))
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(confirming ? Palette.accentInk : Palette.fg)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(confirming ? Palette.warn : Palette.bg))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(confirming ? Palette.warn : Palette.line, lineWidth: 1))
            }
            .buttonStyle(PressScale())
            .sensoryFeedback(.warning, trigger: confirming) { _, new in new }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.surface2))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.accent, lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: confirming)
    }

    private func tap() {
        guard confirming else {
            confirming = true
            resetTask?.cancel()
            resetTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { confirming = false }
            }
            return
        }
        resetTask?.cancel()
        confirming = false
        onEnd()
    }
}

/// Botón del inicio que muestra el entrenamiento en curso.
struct LiveButton: View {
    let dayName: String
    let start: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                BlinkingDot()
                Text(dayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.fg)
                    .lineLimit(1)
                Spacer(minLength: 6)
                TimelineView(.periodic(from: start, by: 1)) { ctx in
                    Text(formatElapsed(ctx.date.timeIntervalSince(start)))
                        .font(.display(30, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface2))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.accent, lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }
}

struct RecordChip: View {
    let weight: Double

    var body: some View {
        Label("Récord \(fmtW(weight))", systemImage: "medal.fill")
            .font(.display(14, weight: .bold))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundStyle(Palette.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Palette.gold.opacity(0.14)))
    }
}

// MARK: - Gráficos

struct Sparkline: View {
    let points: [ProgressPoint]

    var body: some View {
        let weights = points.map(\.weight)
        let hi = weights.max() ?? 1
        let lo = weights.min() ?? 0
        let pad = hi == lo ? 1.0 : 0.0
        Chart(Array(points.enumerated()), id: \.offset) { item in
            LineMark(x: .value("Vez", item.offset), y: .value("Kg", item.element.weight))
                .foregroundStyle(Palette.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .allowsHitTesting(false)
    }
}

struct ProgressChart: View {
    let points: [ProgressPoint]

    var body: some View {
        let weights = points.map(\.weight)
        let hi = weights.max() ?? 1
        let lo = weights.min() ?? 0
        let pad = hi == lo ? 1.0 : 0.0
        let maxIndex = weights.lastIndex(of: hi) ?? 0
        let last = max(points.count - 1, 0)
        let lastWeight = points.last?.weight ?? 0
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { item in
                AreaMark(
                    x: .value("Vez", item.offset),
                    yStart: .value("Base", lo - pad),
                    yEnd: .value("Kg", item.element.weight)
                )
                .foregroundStyle(Palette.accent.opacity(0.12))
                LineMark(x: .value("Vez", item.offset), y: .value("Kg", item.element.weight))
                    .foregroundStyle(Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            PointMark(x: .value("Vez", maxIndex), y: .value("Kg", hi))
                .foregroundStyle(Palette.gold.opacity(0.35))
                .symbolSize(120)
            PointMark(x: .value("Vez", last), y: .value("Kg", lastWeight))
                .foregroundStyle(maxIndex == last ? Palette.gold : Palette.accent)
                .symbolSize(45)
        }
        .chartXScale(domain: 0...max(last, 1))
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .allowsHitTesting(false)
    }
}

struct ProgressChartBox: View {
    let points: [ProgressPoint]
    let today: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progreso · mejor serie").eyebrow(11)
                Spacer()
                if points.count >= 2, let hi = points.map(\.weight).max() {
                    Text("Máx \(fmtW(hi)) kg")
                        .font(.display(12, weight: .bold))
                        .foregroundStyle(Palette.gold)
                }
            }
            if points.count >= 2 {
                ProgressChart(points: points)
                    .frame(minHeight: 60, maxHeight: .infinity)
                HStack {
                    Text(Dates.short(points[0].date))
                    Spacer()
                    Text(points[points.count - 1].date == today ? "hoy" : Dates.short(points[points.count - 1].date))
                }
                .font(.display(11, weight: .semibold))
                .foregroundStyle(Palette.muted)
            } else {
                Text("Se dibuja a partir de la segunda vez que hagas este ejercicio.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.bg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }
}
