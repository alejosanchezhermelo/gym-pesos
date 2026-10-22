import SwiftUI

enum Screen: Equatable {
    case home
    case day(Int)
}

enum ActiveSheet: Identifiable, Equatable {
    case exercise(day: Int, index: Int)
    case summary(SessionLog)
    case settings

    var id: String {
        switch self {
        case .exercise(let d, let i): "ex-\(d)-\(i)"
        case .summary(let log): "summary-\(log.id)"
        case .settings: "settings"
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var screen: Screen = .home
    @State private var forward = true
    @State private var sheet: ActiveSheet?

    private var store: Store { Store.shared }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            switch screen {
            case .home:
                HomeView(
                    openDay: { go(.day($0), forward: true) },
                    openSettings: { sheet = .settings }
                )
                .transition(slide)
            case .day(let i):
                DayView(
                    dayIndex: i,
                    back: { go(.home, forward: false) },
                    openExercise: { j in
                        store.openExercise(dayIndex: i, exerciseIndex: j)
                        sheet = .exercise(day: i, index: j)
                    }
                )
                .transition(slide)
            }

            if sheet == nil, let c = store.celebration {
                MedalOverlay(celebration: c)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.celebration)
        .sheet(item: $sheet) { s in
            sheetContent(s)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            store.onForeground()
            showPendingSummary()
        }
        .onChange(of: store.data.pendingSummary) { _, _ in
            if scenePhase == .active { showPendingSummary() }
        }
    }

    private var slide: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(x: forward ? 28 : -28)),
            removal: .opacity
        )
    }

    private func go(_ target: Screen, forward: Bool) {
        self.forward = forward
        withAnimation(.easeOut(duration: 0.3)) { screen = target }
    }

    private func showPendingSummary() {
        if let log = store.takePendingSummary() {
            sheet = .summary(log)
        }
    }

    @ViewBuilder
    private func sheetContent(_ s: ActiveSheet) -> some View {
        Group {
            switch s {
            case .exercise(let d, let i):
                ExerciseSheet(dayIndex: d, exerciseIndex: i)
            case .summary(let log):
                SummarySheet(log: log)
            case .settings:
                SettingsSheet()
            }
        }
        .overlay {
            if let c = store.celebration {
                MedalOverlay(celebration: c)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.celebration)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Palette.surface)
        .preferredColorScheme(.dark)
    }
}
