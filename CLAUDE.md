# Gym Pesos — contexto para Claude

App nativa de iPhone (SwiftUI) para anotar pesos y reps en el gym. Es un port de una maqueta web
(`C:\Users\Compras\Downloads\gym.html`, ya superada por la app). Se instala gratis con **SideStore**
(Apple ID gratuito). Repo público: https://github.com/alejosanchezhermelo/gym-pesos (rama `main`).

## El usuario
- Habla español rioplatense (voseo). Responder en español, pasos cortos y claros. No es programador.
- Sin Mac: PC con Windows. iPhone 16 Pro Max (iOS 27), Apple Watch Series 11.
- **Antes de construir algo nuevo, proponer el diseño y esperar su OK.** No agregar cosas que no pidió:
  una vez no le gustó un cambio no pedido. Si algo pedido queda afuera, decirlo.
- Al terminar un build: decir qué cambió, el link de instalación y el link para volver a la versión anterior.
- Para mostrarle archivos en el celular (Remote Control) usar SendUserFile.

## Cómo se compila y publica (no hay Mac)
1. Cambios en el código → subir `MARKETING_VERSION` y `CURRENT_PROJECT_VERSION` en `project.yml`.
2. `git commit` + `git push origin main` → GitHub Actions (`.github/workflows/build.yml`, macOS):
   XcodeGen → `xcodebuild` sin firmar → firma ad-hoc → `GymPesos.ipa` → Release `build-N` (latest).
3. Esperar: `gh run watch <id> -R alejosanchezhermelo/gym-pesos` y revisar
   `gh run view <id> --log | grep " error:"`. El workflow exige `BUILD SUCCEEDED` (antes una falla
   publicó un .ipa roto). Si falla, corregir y volver a subir.
4. Opcional: bajar el .ipa y revisar `Info.plist` / binario con Python `zipfile` + `plistlib`.
- `gh` está en `C:\Program Files\GitHub CLI` (en Bash: `export PATH="$PATH:/c/Program Files/GitHub CLI"`).
- Cambios solo de documentación: poner `[skip ci]` en el commit para no generar un build.
- Links para el usuario:
  - última: `https://github.com/alejosanchezhermelo/gym-pesos/releases/latest/download/GymPesos.ipa`
  - una versión: `.../releases/download/build-N/GymPesos.ipa`
- Instalar: Safari → descargar → SideStore → My Apps → + → elegir el .ipa →
  **"Register App ID for Each Extension"** (nunca "Remove App Extensions").

## Límites del Apple ID gratis (no intentar de nuevo)
- Sin push, App Groups, iCloud ni HealthKit (HealthKit se probó: SideStore quita el permiso).
- Por eso el widget no puede leer datos de la app: la Live Activity recibe todo en su `ContentState`.
- 10 App IDs por semana: se usan 3 (SideStore, la app, `.widget`). **No cambiar los bundle IDs**
  (`com.alejosanchez.gympesos` y `com.alejosanchez.gympesos.widget`): actualizar reusa los mismos.
- SideStore se renueva solo con una automatización de Atajos (6:20, diaria: conecta LocalDevVPN,
  "Refresh All Apps", espera 90 s, desconecta). Si el login de SideStore falla (-80045): servidor
  anisette Jkcoxson y "On-Device Anisette" apagado.
- Si aparece "pairing file is invalid or missing (.rppairing UDID not found)": iPhone por cable a la
  PC → iloader → Manage Pairing File → **Place** en SideStore → LocalDevVPN + Refresh All.
  Pasó el 2026-10-26 y se arregló así.

## Estructura
- `project.yml` — XcodeGen. iOS 18+. App con `SWIFT_ACTIVE_COMPILATION_CONDITIONS = APP_TARGET`.
- `Shared/` (app + extensión): `WorkoutAttributes.swift` (estado de la Live Activity, `AppTheme`,
  `Palette`, `Font.display`, `fmtW`), `WorkoutIntents.swift` (botones de la Live Activity).
- `GymPesos/` (app):
  - `Model.swift` — datos `Codable` (`AppData`, rutina, `HistoryEntry`, `Session`, `SessionLog`,
    `SetScore`), datos de ejemplo (rutina de Roberto) y ayudas de formato.
  - `Store.swift` — estado único `@Observable @MainActor` guardado en JSON (Application Support):
    series, récords, entrenamiento, superseries, editor, Live Activity. `Stats.swift`: cálculos
    del inicio y Progreso.
  - `Services.swift` — avisos locales (récord → vibra el reloj) y vibración de festejo (Core Haptics).
  - `Import/` — importar planilla del profe (PDF con PDFKit, .xlsx con lector zip propio, CSV, texto).
  - `Views/` — `ContentView` (raíz y hojas), `HomeView` (pestañas Entrenar/Progreso/Historial),
    `HomeCards`, `DayView`, `ExerciseSheet`, `DayEditorSheet`, `ProgressTab`, `HistoryTab`
    (+ `BodyWeightSheet`), `SummarySheet`, `SettingsSheet`, `ImportSheet`, `MedalOverlay`,
    `ExerciseFigure` (muñequito animado), `Components`.
- `GymWidget/` — Live Activity: pantalla de bloqueo, isla dinámica y Apple Watch (`.small`).
- `Instaladores/` — instaladores de Windows (iTunes, iloader); está en `.gitignore`.

## Reglas técnicas (errores que ya pasaron)
- **Nunca** `data.session?.x = f()` si `f` lee `data`: rompe el acceso exclusivo y cierra la app.
  Calcular en una variable local y después asignar.
- Campos nuevos en los `Codable` guardados: **siempre opcionales** (o con valor por defecto en
  `ContentState`), si no se pierden los datos al actualizar.
- Los botones de la Live Activity son `LiveActivityIntent`: corren en la app; el cuerpo va en
  `#if APP_TARGET`. Mandan ejercicio + serie y el Store los ignora si no coinciden (toques repetidos).
- La extensión no lee ajustes de la app: lo que necesite (tema, reps, etc.) va en `ContentState`.
- Funciones globales no pueden usar estáticos del `Store` (`@MainActor`): marcarlos `nonisolated`.
- Swift 5 en modo de lenguaje; no usar regex con `/.../` (usar `NSRegularExpression`).

## Qué tiene la app (versión 1.6.1, build-12; 1.6/build-11 probada y funcionando)
- Días de la rutina; ejercicios con peso **y reps** por serie (+/−), tilde por serie.
- Ejercicios **sin peso** (cuentan reps). Récord: más peso, o mismo peso con más reps.
- Hoja del ejercicio: figurita animada, gráfico de progreso, historial, "tu peso × N".
- Entrenamiento: deslizar para arrancar, cronómetro, Terminar con confirmación, cierre automático
  al completar el día, cada entrenamiento empieza de cero (varios por día), resumen al terminar.
- **Superseries** armadas en el momento (solo para ese entrenamiento).
- Live Activity: ± kg, ± reps, Serie hecha, Saltar, Terminar; isla dinámica; reloj con ✓.
- Récord: medalla + vibración; con la app cerrada, aviso que vibra en el reloj.
- Inicio: saludo, "Te toca", tarjetas de colores deslizables (semana/racha, cerca de un récord,
  peso corporal, último récord, este mes). Pestañas Progreso (mes, calendario, récords, peso)
  e Historial (resúmenes, borrar).
- Editor de rutina (con pasar historial al renombrar, reiniciar ejercicio), agregar/borrar días,
  importar planilla (PDF: prueba 3 formas de leerlo y usa la que encuentra más ejercicios). Ajustes: nombre, objetivo semanal, 6 temas + ícono, salto de peso,
  probar aviso, reiniciar estadísticas.

## Ideas pendientes (no pedidas todavía; preguntar antes)
Copia de seguridad (exportar/restaurar, la más recomendada), pantalla siempre prendida al entrenar,
Siri ("serie hecha"), sugerencia de cuánto subir, series de calentamiento, objetivos por ejercicio,
mandar progreso al profe (el usuario dijo "más adelante"), widget "Entrenar"/control del botón de Acción.
