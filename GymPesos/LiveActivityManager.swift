import ActivityKit
import Foundation

/// Arranca y termina la Live Activity del entrenamiento. Todo local, sin push.
enum LiveActivityManager {
    static func start(at startDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Nunca más de una a la vez.
        if !Activity<WorkoutAttributes>.activities.isEmpty { return }
        let content = ActivityContent(
            state: WorkoutAttributes.ContentState(startDate: startDate),
            staleDate: nil
        )
        do {
            _ = try Activity.request(
                attributes: WorkoutAttributes(title: "Entrenando"),
                content: content,
                pushType: nil
            )
        } catch {
            print("No se pudo iniciar la Live Activity: \(error)")
        }
    }

    static func endAll() async {
        for activity in Activity<WorkoutAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Al abrir la app: que la Live Activity coincida con el estado guardado.
    static func sync(startDate: Date?) async {
        if let startDate {
            start(at: startDate)
        } else {
            await endAll()
        }
    }
}
