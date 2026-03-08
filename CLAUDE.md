# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS + Apple Watch harm-reduction app that tracks alcohol intake, estimates BAC in real-time using the Widmark formula, and runs AI-powered intoxication analysis combining voice (Whisper slur detection), face (Presage SmartSpectra + Vision), and Apple Watch health data.

## Commands

### Secrets setup (required before first build)
```bash
cp .env.example .env.local      # then fill in your keys
./scripts/apply_env.sh          # generates DrinkingTracker/Secrets.swift (gitignored)
```
Re-run `apply_env.sh` whenever `.env.local` changes. Keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`, `VULTURE_SERVER_URL`, `SMART_SPECTRA_API_KEY`.

### Generate & Open Xcode Project
```bash
xcodegen generate
open DrinkingTracker.xcodeproj
```
Must be re-run after modifying `project.yml` **and** after adding new `.swift` files — Xcode does not auto-detect them, causing silent "type not found" compile errors.

### Vulture ML Server
```bash
cd vulture-server
source venv/bin/activate
python main.py                    # starts on :8000
uvicorn main:app --reload         # alternative with hot-reload
```
Test: `curl -X POST http://localhost:8000/analyze/voice -F "audio=@test.m4a"`
First run downloads ~74 MB Whisper model.

## Architecture

### State Management
`AppState` (`DrinkingTracker/App/AppState.swift`) is the single source of truth, marked `@Observable` (iOS 17). Injected at root via `.environment(appState)`, consumed with `@Environment(AppState.self)`. Holds: Firebase user, session start time, BAC/stage, drink logs, analysis logs, health metrics, scan results, and all sheet-presentation booleans (`showAddDrink`, `showAnalysis`, etc.).

To get a `Binding` from `AppState` inside a view body: `@Bindable var state = appState` as a local variable.

### Navigation & Tab Structure
`RootView` (in `DrinkingTrackerApp.swift`) switches between `LoginView` and `DashboardView` based on `appState.isLoggedIn` (Firebase auth state listener).

`DashboardView` (`Features/Dashboard/DashboardView.swift`) is the main tab container with 4 tabs:
- 0 `house` — Home (calendar + AI summary)
- 1 `timer` — Session (live timer, drink counter, stage description)
- 2 `bubble.left` — Gemini Chat
- 3 `camera` — Scan (SmartSpectra face analysis)

The tab bar and all per-tab bottom action buttons live exclusively in `DashboardView`. Child tab views (`SessionView`, `ScanView`) only render their scroll content. All sheets (`AddDrinkView`, `AnalysisView`, etc.) are presented from root `DashboardView` via `appState` booleans.

### Design System
`DrinkingTracker/AppTheme.swift` defines all colors, fonts, corner radii, and shadows. Use `AppTheme.Colors.*`, `AppTheme.Fonts.mono()`, `AppTheme.Fonts.title()`, and `.cardShadow()` — never hardcode colors or fonts inline. Watch app uses `WatchApp/WatchTheme.swift` which mirrors the same palette.

### Auth (`Features/Auth/LoginView.swift`)
Firebase Auth: email/password, Sign in with Apple (nonce + SHA256, `AuthenticationServices`), Google Sign-In (`GoogleSignIn` SDK). `LoginView` handles sign-up (inline toggle) and password reset.

### Data Flow
1. Drink added → `DrinkLogViewModel` saves to Supabase → inserts into `appState.drinkLogs` → `appState.refreshBAC()` → `WatchSessionManager.shared.syncToWatch(...)` pushes update to watch
2. Session starts → `appState.startSession()` → `AutoAnalysisTimer` fires every 15 min → `appState.showAnalysis = true`
3. Manual scan: `AnalysisViewModel` orchestrates — Watch data (WatchConnectivity), face photo (Vision), audio POST to Vulture, Gemini summary, saves `AnalysisLog` to Supabase
4. Intoxication stage = composite of BAC (65%) + scan signals (35%): focus, red eyes, droopy eyelids, flushed face, heart rate — see `IntoxicationStage.from(bac:scanResults:)`

### Services (all singletons via `.shared`)
- `SupabaseService` — wraps `supabase-swift` v2; all queries use `async/await` and `.execute().value` decoding
- `GeminiService` — `stageSummary()` for analysis, `startChat()`/`sendChatMessage()` for chatbot
- `VultureService` — multipart POST to FastAPI; returns `VultureResponse` with `transcript` + `slurScore`
- `HealthKitService` — reads last-hour HR, HRV, SpO2; call `refreshAll()` before analysis
- `WatchSessionManager` (iOS) — `syncToWatch()` pushes auth+session state, `requestAnalysis()` triggers watch capture, receives health dict + 30s audio, POSTs audio to Vulture, computes drunkenness score (0–100), sends score back to watch

### SmartSpectra (Scan tab)
SDK configured once in `DrinkingTrackerApp.init()`:
```swift
SmartSpectraSwiftSDK.shared.setApiKey(Config.smartSpectraAPIKey)
SmartSpectraSwiftSDK.shared.setSmartSpectraMode(.continuous)
SmartSpectraSwiftSDK.shared.setCameraPosition(.front)
SmartSpectraSwiftSDK.shared.setImageOutputEnabled(true)
```
`ScanView` uses `@ObservedObject var sdk = SmartSpectraSwiftSDK.shared` and `@ObservedObject var vitalsProcessor = SmartSpectraVitalsProcessor.shared`. `SmartSpectraView()` (no params) owns the camera and session lifecycle — do NOT call `startMeasurement()`/`startProcessing()` manually when using it. Poll `sdk.edgeMetrics?.pulse.rate.last?.value` for real-time heart rate. `vitalsProcessor.imageOutput` (a `UIImage?`) provides frames for Vision face analysis. Requires physical device — simulator unsupported.

### iPhone ↔ Watch Communication
- iPhone: `DrinkingTracker/Services/WatchSessionManager.swift` — `syncToWatch()` called on login and every BAC refresh; receives audio from watch, POSTs to Vulture, computes score, sends back via `updateApplicationContext`
- Watch: `WatchApp/WatchSessionManager.swift` — `WatchSessionManagerWatch` (ObservableObject) handles WCSession, records 30s audio with `AVAudioSession`, tracks movement via `CMMotionManager` accelerometer (stdDev = impairment score), reads HealthKit; receives auth + score from phone via `didReceiveApplicationContext`

### Watch App Architecture
`WatchAppState` (`WatchApp/WatchAppState.swift`) is the watch's `@Observable` singleton — holds auth, BAC, stage, drinks, HR, drunkenness score. Injected via `.environment(WatchAppState.shared)`.

`WatchRootView` routes between `WatchLoginView` (not yet authenticated) and `WatchDashboardView` (2-page swipe TabView: Status + Record). Auth is synced from iPhone via `updateApplicationContext` — there is no independent login on the watch.

`WatchDashboardView` shows `.alert()` with haptic (`WKInterfaceDevice.current().play(.notification)`) when stage ≥ `.drunk` (rawValue 3) or drink count hits multiples of 5.

Watch drunkenness score formula: slurScore×40% + hrAnomaly×25% + movementScore×15%, normalized to 0–100.

### Vulture Server
FastAPI at `vulture-server/main.py`. `routes/voice.py`:
1. `whisper_model.py` — lazy-loaded `openai-whisper` base model
2. `slur_detector.py` — 4 heuristics → 0.0–1.0

### Database (Supabase)
Three tables: `user_profiles`, `drink_logs`, `analysis_logs`. Schema in `supabase/migrations/001_initial.sql`. All models use snake_case `CodingKeys`. Firebase UID is the `user_id` FK. **`user_profiles` row must exist before any `drink_logs` insert** — `DashboardView.loadInitialData()` auto-creates a default profile on first login.

## Configuration

Credentials flow: `.env.local` → `scripts/apply_env.sh` → `DrinkingTracker/Secrets.swift` (gitignored) → `DrinkingTracker/Config.swift`.

`GoogleService-Info.plist` (from Firebase Console) must be manually dragged into the Xcode target after `xcodegen generate` — it is gitignored. The `REVERSED_CLIENT_ID` from this plist must match `project.yml` under `CFBundleURLTypes`.

Vulture server URL in `.env.local` must be the machine's LAN IP (not `localhost`) when running on a physical device.

## Key Constraints

- **`xcodegen generate` required** after any new `.swift` file is added — Xcode silently omits them otherwise
- **Physical device required**: HealthKit, WatchConnectivity, SmartSpectra camera, and WatchKit do not work in Simulator
- **`@Observable` on iPhone (iOS 17+)**: Never use `ObservableObject`/`@Published` in the iPhone app; use `@Observable` + `@Bindable`
- **`WatchSessionManagerWatch` uses `ObservableObject`**: watchOS uses `@Published`; `WatchAppState` uses `@Observable` (watchOS 10+)
- **SmartSpectra requires physical device**: Simulator camera is unsupported by the SDK
