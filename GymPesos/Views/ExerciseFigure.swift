import SwiftUI

// Figurita animada que muestra cómo se hace cada ejercicio.
// Es el mismo dibujo de la maqueta (gym.html): un muñequito en un lienzo de 160 × 112
// que va y vuelve entre la pose A y la pose B.

struct ExerciseFigure: View {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motion = Motions.motion(for: name)
        VStack(spacing: 2) {
            if let motion {
                TimelineView(.animation(paused: reduceMotion)) { ctx in
                    let phase = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6
                    let t = reduceMotion ? 1 : 0.5 - 0.5 * cos(phase * 2 * .pi)
                    FigureCanvas(prims: motion.draw(t))
                }
                .aspectRatio(160 / 112, contentMode: .fit)
                Text(motion.front ? "Vista de frente" : "Vista de costado")
                    .font(.display(11, weight: .semibold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.muted)
                    .padding(.bottom, 4)
            } else {
                Text("Sin animación")
                    .font(.display(11, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.bg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("Cómo se hace: \(name)")
    }
}

// MARK: - Dibujo

struct P {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    var cg: CGPoint { CGPoint(x: x, y: y) }
}

enum Prim {
    case line(P, P, Color, Double, [CGFloat], Double)
    case circle(P, Double, Color?, Color?, Double)
    case rect(Double, Double, Double, Double, Double, Color, Double)
}

private struct FigureCanvas: View {
    let prims: [Prim]

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 160, size.height / 112)
            ctx.translateBy(x: (size.width - 160 * s) / 2, y: (size.height - 112 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            for prim in prims {
                switch prim {
                case let .line(a, b, color, width, dash, opacity):
                    var path = Path()
                    path.move(to: a.cg)
                    path.addLine(to: b.cg)
                    ctx.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
                    )
                case let .circle(c, r, fill, stroke, width):
                    let path = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                    if let fill { ctx.fill(path, with: .color(fill)) }
                    if let stroke { ctx.stroke(path, with: .color(stroke), lineWidth: width) }
                case let .rect(x, y, w, h, rx, color, opacity):
                    let path = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: rx)
                    ctx.fill(path, with: .color(color.opacity(opacity)))
                }
            }
        }
    }
}

/// Acumula lo que hay que dibujar.
struct Drawer {
    var prims: [Prim] = []

    /// Hueso del cuerpo (verde si es el músculo que trabaja).
    mutating func bone(_ a: P, _ b: P, hl: Bool = false, opacity: Double = 1) {
        prims.append(.line(a, b, hl ? Palette.accent : Palette.fg, 5, [], opacity))
    }

    /// Caño de máquina o banco.
    mutating func pipe(_ a: P, _ b: P) {
        prims.append(.line(a, b, Palette.muted, 3, [], 1))
    }

    mutating func cable(_ a: P, _ b: P) {
        prims.append(.line(a, b, Palette.muted, 1.2, [3, 3], 1))
    }

    mutating func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, rx: Double = 2, opacity: Double = 1) {
        prims.append(.rect(x, y, w, h, rx, Palette.muted, opacity))
    }

    mutating func head(_ c: P) {
        prims.append(.circle(c, 7, Palette.fg, nil, 0))
    }

    mutating func floor() {
        prims.append(.line(P(4, 108), P(156, 108), Palette.line, 2, [], 1))
    }

    // Cargas
    mutating func dumbbell(_ h: P, opacity: Double = 1) {
        prims.append(.rect(h.x - 5, h.y - 2.5, 10, 5, 2, Palette.fg, 0.75 * opacity))
    }

    mutating func plate(_ h: P) {
        prims.append(.circle(h, 6.5, Palette.surface2, Palette.fg, 2))
    }

    mutating func handle(_ h: P) {
        prims.append(.circle(h, 3, Palette.fg, nil, 0))
    }

    mutating func pad(_ c: P) {
        prims.append(.circle(c, 5, Palette.surface2, Palette.muted, 2))
    }

    // Aparatos
    mutating func benchLow() {
        box(36, 67, 66, 5)
        pipe(P(44, 72), P(44, 108))
        pipe(P(94, 72), P(94, 108))
    }

    mutating func seat(_ x: Double) {
        box(x - 16, 78, 32, 5)
        pipe(P(x, 83), P(x, 108))
    }

    mutating func cableTo(_ from: P, _ to: P) {
        cable(from, to)
        prims.append(.circle(to, 3.5, Palette.muted, nil, 0))
    }
}

// MARK: - Poses

private let R = Double.pi / 180
private enum Len {
    static let torso = 32.0, upperArm = 17.0, forearm = 16.0, thigh = 22.0, shin = 21.0
}

private func pol(_ p: P, _ a: Double, _ l: Double) -> P {
    P(p.x + cos(a * R) * l, p.y + sin(a * R) * l)
}

/// Cinemática inversa de dos segmentos: devuelve la articulación y el extremo.
private func ik(_ a: P, _ b: P, _ l1: Double, _ l2: Double, _ s: Double) -> (P, P) {
    let dx = b.x - a.x, dy = b.y - a.y
    let d = max(0.001, min(hypot(dx, dy), l1 + l2 - 0.01))
    let c = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    let ang = atan2(dy, dx) + s * acos(max(-1, min(1, c)))
    let j = P(a.x + cos(ang) * l1, a.y + sin(ang) * l1)
    let e = atan2(b.y - j.y, b.x - j.x)
    return (j, P(j.x + cos(e) * l2, j.y + sin(e) * l2))
}

struct Pose {
    var hip: P?
    var sh: P?
    var ankle: P?
    var hand: P?
    var handRel: P?
    var torso: Double?
    var th: Double?
    var sn: Double?
    var ua: Double?
    var fa: Double?
    var ua2: Double?
    var fa2: Double?
    var hb: Double?
    var kb: Double?
    var arm: Double?
    var len: Double?
    var plank = false

    func with(_ change: (inout Pose) -> Void) -> Pose {
        var copy = self
        change(&copy)
        return copy
    }

    static func lerp(_ a: Pose, _ b: Pose, _ t: Double) -> Pose {
        func n(_ x: Double?, _ y: Double?) -> Double? {
            guard let x else { return nil }
            guard let y else { return x }
            return x + (y - x) * t
        }
        func p(_ x: P?, _ y: P?) -> P? {
            guard let x else { return nil }
            guard let y else { return x }
            return P(x.x + (y.x - x.x) * t, x.y + (y.y - x.y) * t)
        }
        return Pose(
            hip: p(a.hip, b.hip), sh: p(a.sh, b.sh), ankle: p(a.ankle, b.ankle), hand: p(a.hand, b.hand),
            handRel: p(a.handRel, b.handRel), torso: n(a.torso, b.torso), th: n(a.th, b.th), sn: n(a.sn, b.sn),
            ua: n(a.ua, b.ua), fa: n(a.fa, b.fa), ua2: n(a.ua2, b.ua2), fa2: n(a.fa2, b.fa2),
            hb: n(a.hb, b.hb), kb: n(a.kb, b.kb), arm: n(a.arm, b.arm), len: n(a.len, b.len), plank: a.plank
        )
    }
}

/// Posición de cada articulación en la vista de costado.
struct SideBody {
    var hip: P
    var sh: P
    var head: P
    var el: P
    var ha: P
    var far: (P, P)?
    var kn: P
    var an: P

    init(_ p: Pose) {
        var hip = p.hip ?? P(0, 0)
        let sh: P
        if let s = p.sh, p.plank, let ankle = p.ankle {
            sh = s
            let dx = ankle.x - s.x, dy = ankle.y - s.y, d = max(0.001, hypot(dx, dy))
            hip = P(s.x + dx / d * Len.torso, s.y + dy / d * Len.torso)
        } else {
            sh = p.sh ?? pol(hip, p.torso ?? 0, Len.torso)
        }
        let td = atan2(sh.y - hip.y, sh.x - hip.x)
        head = P(sh.x + cos(td) * 10, sh.y + sin(td) * 10)

        func arm(_ ua: Double?, _ fa: Double?) -> (P, P) {
            let bend = p.hb.flatMap { $0 == 0 ? nil : $0 } ?? 1
            if let hand = p.hand { return ik(sh, hand, Len.upperArm, Len.forearm, bend) }
            if let rel = p.handRel { return ik(sh, P(sh.x + rel.x, sh.y + rel.y), Len.upperArm, Len.forearm, bend) }
            let e = pol(sh, ua ?? 0, Len.upperArm)
            return (e, pol(e, fa ?? 0, Len.forearm))
        }
        (el, ha) = arm(p.ua, p.fa)
        far = p.ua2 != nil ? arm(p.ua2, p.fa2) : nil

        if let ankle = p.ankle {
            let bend = p.kb.flatMap { $0 == 0 ? nil : $0 } ?? -1
            (kn, an) = ik(hip, ankle, Len.thigh, Len.shin, bend)
        } else {
            kn = pol(hip, p.th ?? 0, Len.thigh)
            an = pol(kn, p.sn ?? 0, Len.shin)
        }
        self.hip = hip
        self.sh = sh
    }
}

enum Load { case dumbbell, plate, handle }
enum Limb { case arm, leg }

struct Motion {
    var front = false
    var hl: Limb?
    var load: Load?
    var bust = false
    var seat = false
    /// Aparatos detrás (`true`) o delante (`false`) del cuerpo.
    var props: ((SideBody, Bool, inout Drawer) -> Void)?
    var a: Pose
    var b: Pose

    func draw(_ t: Double) -> [Prim] {
        var d = Drawer()
        let p = Pose.lerp(a, b, t)
        if front { drawFront(p, &d) } else { drawSide(p, &d) }
        return d.prims
    }

    private func put(_ load: Load?, at h: P, opacity: Double = 1, _ d: inout Drawer) {
        switch load {
        case .dumbbell: d.dumbbell(h, opacity: opacity)
        case .plate: d.plate(h)
        case .handle: d.handle(h)
        case nil: break
        }
    }

    private func drawSide(_ p: Pose, _ d: inout Drawer) {
        let q = SideBody(p)
        let hA = hl == .arm, hL = hl == .leg
        d.floor()
        props?(q, true, &d)
        if let far = q.far {
            d.bone(q.sh, far.0, hl: hA, opacity: 0.38)
            d.bone(far.0, far.1, hl: hA, opacity: 0.38)
            put(load, at: far.1, opacity: 0.38, &d)
        }
        d.bone(q.hip, q.kn, hl: hL)
        d.bone(q.kn, q.an, hl: hL)
        d.bone(q.hip, q.sh)
        d.head(q.head)
        d.bone(q.sh, q.el, hl: hA)
        d.bone(q.el, q.ha, hl: hA)
        props?(q, false, &d)
        put(load, at: q.ha, &d)
    }

    private func drawFront(_ p: Pose, _ d: inout Drawer) {
        let cx = 80.0, sy = 34.0
        let len = (Len.upperArm + Len.forearm) * (p.len ?? 1)
        let arm = p.arm ?? 0
        d.floor()
        if bust { d.box(66, 46, 28, 60, rx: 3, opacity: 0.45) }
        if seat { d.box(60, 66, 40, 5) }
        d.head(P(cx, 20))
        d.bone(P(cx, 28), P(cx, 64))
        d.bone(P(68, sy), P(92, sy))
        if !bust {
            if seat {
                d.bone(P(74, 64), P(72, 76)); d.bone(P(72, 76), P(72, 104))
                d.bone(P(86, 64), P(88, 76)); d.bone(P(88, 76), P(88, 104))
            } else {
                d.bone(P(80, 64), P(72, 105)); d.bone(P(80, 64), P(88, 105))
            }
        }
        for (x, a) in [(68.0, 90 + arm), (92.0, 90 - arm)] {
            let h = pol(P(x, sy), a, len)
            d.bone(P(x, sy), h, hl: true)
            d.dumbbell(h)
        }
    }
}

// MARK: - Catálogo de movimientos

enum Motions {
    private static let stand = Pose(hip: P(72, 64), ankle: P(72, 105), torso: -90)
    private static let lie = Pose(hip: P(96, 62), torso: 180, th: 30, sn: 95)
    private static let sit = Pose(hip: P(70, 76), torso: -90, th: 0, sn: 90)

    static func motion(for name: String) -> Motion? {
        guard let id = id(for: name) else { return nil }
        return all[id]
    }

    /// Qué movimiento corresponde a cada nombre de ejercicio.
    static func id(for name: String) -> String? {
        let n = exerciseKey(name)
        func has(_ words: String...) -> Bool { words.contains { n.contains($0) } }
        if has("frances") { return "frances" }
        if has("press militar", "press hombro", "press arnold", "press de hombro") { return "militar" }
        if has("press") { return "bench" }
        if has("apertura", "cruce", "pec deck") { return "fly" }
        if has("flexion") { return "pushup" }
        if has("pullover") { return "pullover" }
        if has("femoral", "camilla") { return "legcurl" }
        if has("scott") { return "scott" }
        if has("concentrado") { return "conc" }
        if has("alternado") { return "curlalt" }
        if has("curl") { return has("barra") ? "curlbar" : "curl" }
        if has("cuadricep", "sillon") { return "legext" }
        if has("sentadilla", "prensa", "squat") { return "squat" }
        if has("peso muerto", "rumano") { return "rdl" }
        if has("vuelos lat", "elevaciones lat", "laterales") { return "lateral" }
        if has("vuelos front", "elevaciones front", "frontales") { return "frontr" }
        if has("posterior", "pajaro") { return "rear" }
        if has("jalon", "dominada") { return "pulldown" }
        if has("remo") { return has("mancuerna", "un brazo") ? "onerow" : "row" }
        if has("fondo") { return "dips" }
        if has("patada") { return "kickback" }
        if has("extension", "polea") { return "pushdown" }
        return nil
    }

    static let all: [String: Motion] = [
        "curl": Motion(hl: .arm, load: .dumbbell,
                       a: stand.with { $0.ua = 92; $0.fa = 90 },
                       b: stand.with { $0.ua = 82; $0.fa = -72 }),
        "curlbar": Motion(hl: .arm, load: .plate,
                          a: stand.with { $0.ua = 92; $0.fa = 90 },
                          b: stand.with { $0.ua = 82; $0.fa = -72 }),
        "curlalt": Motion(hl: .arm, load: .dumbbell,
                          a: stand.with { $0.ua = 92; $0.fa = 90; $0.ua2 = 82; $0.fa2 = -72 },
                          b: stand.with { $0.ua = 82; $0.fa = -72; $0.ua2 = 92; $0.fa2 = 90 }),
        "scott": Motion(hl: .arm, load: .dumbbell,
                        props: { q, back, d in
                            guard back else { return }
                            d.seat(70)
                            let elbowPad = P(q.el.x + 1, q.el.y + 5)
                            d.pipe(pol(q.sh, 45, 3), elbowPad)
                            d.pipe(elbowPad, P(q.el.x + 1, 104))
                        },
                        a: sit.with { $0.torso = -82; $0.ua = 48; $0.fa = 48 },
                        b: sit.with { $0.torso = -82; $0.ua = 48; $0.fa = -82 }),
        "conc": Motion(hl: .arm, load: .dumbbell,
                       props: { _, back, d in guard back else { return }; d.seat(70) },
                       a: sit.with { $0.torso = -52; $0.ua = 88; $0.fa = 88 },
                       b: sit.with { $0.torso = -52; $0.ua = 88; $0.fa = -70 }),
        "bench": Motion(hl: .arm, load: .plate,
                        props: { _, back, d in guard back else { return }; d.benchLow() },
                        a: lie.with { $0.ua = 72; $0.fa = -88 },
                        b: lie.with { $0.ua = -90; $0.fa = -90 }),
        "pullover": Motion(hl: .arm, load: .dumbbell,
                           props: { _, back, d in guard back else { return }; d.benchLow() },
                           a: lie.with { $0.ua = -90; $0.fa = -90 },
                           b: lie.with { $0.ua = -192; $0.fa = -192 }),
        "frances": Motion(hl: .arm, load: .plate,
                          props: { _, back, d in guard back else { return }; d.benchLow() },
                          a: lie.with { $0.ua = -104; $0.fa = -200 },
                          b: lie.with { $0.ua = -104; $0.fa = -104 }),
        "fly": Motion(front: true, bust: true,
                      a: Pose(arm: 82), b: Pose(arm: 168)),
        "pushup": Motion(hl: .arm,
                         a: Pose(sh: P(52, 74), ankle: P(132, 104), hand: P(52, 105), hb: -1, kb: 1, plank: true),
                         b: Pose(sh: P(52, 92), ankle: P(132, 104), hand: P(52, 105), hb: -1, kb: 1, plank: true)),
        "militar": Motion(hl: .arm, load: .plate,
                          a: stand.with { $0.ua = 62; $0.fa = -96 },
                          b: stand.with { $0.ua = -88; $0.fa = -90 }),
        "frontr": Motion(hl: .arm, load: .dumbbell,
                         a: stand.with { $0.ua = 86; $0.fa = 86 },
                         b: stand.with { $0.ua = -4; $0.fa = -4 }),
        "lateral": Motion(front: true, a: Pose(arm: 8), b: Pose(arm: 86)),
        "rear": Motion(front: true, seat: true, a: Pose(arm: 86, len: 0.3), b: Pose(arm: 86, len: 1)),
        "legext": Motion(hl: .leg,
                         props: { q, back, d in
                             if back {
                                 d.box(52, 80, 36, 5)
                                 d.pipe(P(52, 80), P(48, 44))
                                 d.pipe(P(70, 85), P(70, 108))
                             } else {
                                 d.pad(q.an)
                             }
                         },
                         a: Pose(hip: P(62, 76), torso: -98, th: 0, sn: 88, ua: 80, fa: 10),
                         b: Pose(hip: P(62, 76), torso: -98, th: 0, sn: 6, ua: 80, fa: 10)),
        "squat": Motion(hl: .leg,
                        props: { q, back, d in guard !back else { return }; d.plate(q.sh) },
                        a: stand.with { $0.torso = -88; $0.handRel = P(6, 2); $0.hb = 1 },
                        b: Pose(hip: P(56, 84), ankle: P(72, 105), handRel: P(6, 2), torso: -52, hb: 1)),
        "legcurl": Motion(hl: .leg,
                          props: { q, back, d in
                              if back {
                                  d.box(30, 68, 92, 5)
                                  d.pipe(P(40, 73), P(40, 108))
                                  d.pipe(P(112, 73), P(112, 108))
                              } else {
                                  d.pad(q.an)
                              }
                          },
                          a: Pose(hip: P(80, 63), torso: 180, th: 0, sn: -2, ua: 95, fa: 178),
                          b: Pose(hip: P(80, 63), torso: 180, th: 0, sn: -100, ua: 95, fa: 178)),
        "rdl": Motion(hl: .leg, load: .plate,
                      a: stand.with { $0.ua = 90; $0.fa = 90 },
                      b: Pose(hip: P(62, 63), ankle: P(72, 105), torso: -14, ua: 90, fa: 90)),
        "pulldown": Motion(hl: .arm, load: .handle,
                           props: { q, back, d in
                               if back {
                                   d.seat(70)
                                   d.box(84, 56, 12, 5)
                                   d.cableTo(q.ha, P(74, 4))
                               }
                           },
                           a: sit.with { $0.torso = -94; $0.ua = -82; $0.fa = -88 },
                           b: sit.with { $0.torso = -100; $0.ua = 104; $0.fa = -58 }),
        "row": Motion(hl: .arm, load: .handle,
                      props: { q, back, d in
                          if back {
                              d.box(30, 90, 40, 5)
                              d.box(118, 80, 5, 28)
                              d.cableTo(q.ha, P(150, 88))
                          }
                      },
                      a: Pose(hip: P(50, 88), torso: -84, th: -10, sn: 12, ua: 4, fa: 2),
                      b: Pose(hip: P(50, 88), torso: -96, th: -10, sn: 12, ua: 128, fa: -8)),
        "onerow": Motion(hl: .arm, load: .dumbbell,
                         props: { _, back, d in
                             if back {
                                 d.box(92, 70, 40, 5)
                                 d.pipe(P(128, 75), P(128, 108))
                             }
                         },
                         a: Pose(hip: P(62, 60), ankle: P(60, 105), torso: -8, ua: 90, fa: 90),
                         b: Pose(hip: P(62, 60), ankle: P(60, 105), torso: -8, ua: 202, fa: 95)),
        "dips": Motion(hl: .arm,
                       props: { _, back, d in
                           if back {
                               d.box(26, 66, 26, 5)
                               d.pipe(P(30, 71), P(30, 108))
                               d.pipe(P(48, 71), P(48, 108))
                           }
                       },
                       a: Pose(hip: P(58, 70), sh: P(56, 38), ankle: P(124, 104), hand: P(46, 66), hb: 1, kb: -1),
                       b: Pose(hip: P(60, 88), sh: P(56, 56), ankle: P(124, 104), hand: P(46, 66), hb: 1, kb: -1)),
        "pushdown": Motion(hl: .arm, load: .handle,
                           props: { q, back, d in guard back else { return }; d.cableTo(q.ha, P(96, 4)) },
                           a: stand.with { $0.ua = 96; $0.fa = -50 },
                           b: stand.with { $0.ua = 94; $0.fa = 86 }),
        "kickback": Motion(hl: .arm, load: .dumbbell,
                           a: Pose(hip: P(62, 62), ankle: P(64, 105), torso: -14, ua: 168, fa: 92),
                           b: Pose(hip: P(62, 62), ankle: P(64, 105), torso: -14, ua: 168, fa: 170)),
    ]
}
