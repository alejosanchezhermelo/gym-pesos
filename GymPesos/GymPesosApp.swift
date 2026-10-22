import SwiftUI
import UserNotifications

@main
struct GymPesosApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
