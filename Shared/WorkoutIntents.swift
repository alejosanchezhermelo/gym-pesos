import AppIntents

// Botones de la Live Activity (pantalla de bloqueo, isla dinámica y Apple Watch).
// iOS los ejecuta dentro del proceso de la app, aunque esté cerrada, así que pueden
// leer y guardar los datos sin App Groups. La extensión del widget solo los dibuja.

struct AdjustWeightIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cambiar el peso de la serie"
    static let isDiscoverable = false

    @Parameter(title: "Subir")
    var up: Bool

    @Parameter(title: "Ejercicio")
    var exercise: String

    @Parameter(title: "Serie")
    var setNumber: Int

    init() {}

    init(up: Bool, exercise: String, setNumber: Int) {
        self.up = up
        self.exercise = exercise
        self.setNumber = setNumber
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.adjustCurrentWeight(up: up, exercise: exercise, setNumber: setNumber)
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct AdjustRepsIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cambiar las reps de la serie"
    static let isDiscoverable = false

    @Parameter(title: "Subir")
    var up: Bool

    @Parameter(title: "Ejercicio")
    var exercise: String

    @Parameter(title: "Serie")
    var setNumber: Int

    init() {}

    init(up: Bool, exercise: String, setNumber: Int) {
        self.up = up
        self.exercise = exercise
        self.setNumber = setNumber
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.adjustCurrentReps(up: up, exercise: exercise, setNumber: setNumber)
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Serie hecha"
    static let isDiscoverable = false

    @Parameter(title: "Ejercicio")
    var exercise: String

    @Parameter(title: "Serie")
    var setNumber: Int

    init() {}

    init(exercise: String, setNumber: Int) {
        self.exercise = exercise
        self.setNumber = setNumber
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.completeCurrentSet(exercise: exercise, setNumber: setNumber)
        await Store.shared.drain()
        #endif
        return .result()
    }
}

struct SkipExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Saltar ejercicio"
    static let isDiscoverable = false

    @Parameter(title: "Ejercicio")
    var exercise: String

    init() {}

    init(exercise: String) {
        self.exercise = exercise
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if APP_TARGET
        Store.shared.skipCurrentExercise(exercise: exercise)
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
