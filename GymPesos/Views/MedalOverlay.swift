import SwiftUI

/// Medalla de récord nuevo (la vibración la hace `Haptics.celebrate()`).
struct MedalOverlay: View {
    let celebration: Celebration

    @State private var appeared = false
    @State private var ring = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Palette.bg.opacity(0.55), Palette.bg.opacity(0.9)],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Palette.gold, lineWidth: 3)
                        .frame(width: 96, height: 96)
                        .offset(y: 19)
                        .scaleEffect(ring ? 2.3 : 0.8)
                        .opacity(ring ? 0 : 0.9)
                    MedalArt()
                        .frame(width: 150, height: 170)
                        .scaleEffect(appeared ? 1 : 0.4)
                        .rotationEffect(.degrees(appeared ? 0 : -14))
                        .offset(y: appeared ? 0 : -60)
                        .opacity(appeared ? 1 : 0)
                }
                Text("¡Nuevo récord!")
                    .font(.display(38, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.gold)
                (Text("\(celebration.name) · \(celebration.text) ")
                    + Text("(antes \(celebration.previous))").font(.display(17)).foregroundColor(Palette.muted))
                    .font(.display(22, weight: .semibold))
                    .foregroundStyle(Palette.fg)
                    .multilineTextAlignment(.center)
                Text("Tocá para seguir")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { Store.shared.dismissCelebration(celebration.id) }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { appeared = true }
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) { ring = true }
        }
        .task(id: celebration.id) {
            try? await Task.sleep(for: .seconds(2.6))
            Store.shared.dismissCelebration(celebration.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Dibujo de la medalla de la maqueta (cintas, moneda dorada y estrella).
private struct MedalArt: View {
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 150, sy = size.height / 170
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

            var left = Path()
            left.move(to: p(50, 0)); left.addLine(to: p(76, 0)); left.addLine(to: p(90, 52)); left.addLine(to: p(68, 66))
            left.closeSubpath()
            ctx.fill(left, with: .color(Palette.accent))

            var right = Path()
            right.move(to: p(100, 0)); right.addLine(to: p(74, 0)); right.addLine(to: p(60, 52)); right.addLine(to: p(82, 66))
            right.closeSubpath()
            ctx.fill(right, with: .color(Palette.accent.opacity(0.75)))

            let c = p(75, 104)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 50 * sx, y: c.y - 50 * sy, width: 100 * sx, height: 100 * sy)), with: .color(Palette.gold))
            ctx.stroke(
                Path(ellipseIn: CGRect(x: c.x - 40 * sx, y: c.y - 40 * sy, width: 80 * sx, height: 80 * sy)),
                with: .color(Palette.bg.opacity(0.35)),
                lineWidth: 3
            )

            var star = Path()
            for i in 0..<10 {
                let r: CGFloat = i % 2 == 0 ? 27 : 11.5
                let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let pt = CGPoint(x: c.x + cos(a) * r * sx, y: c.y + 2 * sy + sin(a) * r * sy)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(Palette.bg.opacity(0.85)))
        }
    }
}
