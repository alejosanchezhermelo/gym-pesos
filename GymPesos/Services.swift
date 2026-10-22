import CoreHaptics
import UIKit
import UserNotifications

/// Avisos locales (no son push, funcionan con Apple ID gratis).
/// Con el iPhone bloqueado, iOS los pasa al Apple Watch y vibra en la muñeca.
enum Notifier {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func record(name: String, weight: Double, previous: Double) async {
        let content = UNMutableNotificationContent()
        content.title = "🏅 ¡Nuevo récord!"
        content.body = "\(name) · \(fmtW(weight)) kg (antes \(fmtW(previous)) kg)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "record-\(UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Aviso de prueba a los 5 segundos, para bloquear el celular y ver si vibra el reloj.
    static func test() async {
        let content = UNMutableNotificationContent()
        content.title = "🏅 Aviso de prueba"
        content.body = "Así te va a llegar un récord nuevo."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// Muestra los avisos también con la app abierta.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

/// Vibración de festejo: tres golpes cortos y uno fuerte.
@MainActor
enum Haptics {
    private static var engine: CHHapticEngine?

    static func celebrate() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            if engine == nil {
                let e = try CHHapticEngine()
                e.isAutoShutdownEnabled = true
                engine = e
            }
            try engine?.start()
            var events = [0.0, 0.11, 0.22].map { t in
                tap(at: t, intensity: 0.6, sharpness: 0.5)
            }
            events.append(tap(at: 0.42, intensity: 1, sharpness: 0.9))
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                ],
                relativeTime: 0.42,
                duration: 0.25
            ))
            let player = try engine?.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private static func tap(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }
}
