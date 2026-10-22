import AppIntents

// Botones de la Live Activity (pantalla de bloqueo, isla dinámica y Apple Watch).
// iOS los ejecuta dentro del proceso de la app, aunque esté cerrada, así que pueden
// leer y guardar los datos sin App Groups. La extensión del widget solo los dibuja.

struct AdjustWeightIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cambiar el peso de la serie"
    static let isDiscoverable = false

    @Parameter(title: "Subir")
    var up: Bool

    init() {}

    init(up: Bool) {
        self.up = up
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.adjustCurrentWeight(up: up)
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Serie hecha"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.completeCurrentSet()
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct SkipExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Saltar ejercicio"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.skipCurrentExercise()
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct AskEndIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Terminar entrenamiento"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.setConfirmingEnd(true)
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct CancelEndIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Seguir entrenando"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.setConfirmingEnd(false)
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct ConfirmEndIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Confirmar fin del entrenamiento"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.finishSession(fromLockScreen: true)
        await Store.shared.drain()
        #endif
        return .result()
    }
}
