# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS + Apple Watch harm-reduction app that tracks alcohol intake, estimates BAC in real-time using the Widmark formula, and runs AI-powered intoxication analysis combining voice (Whisper slur detection), face (Vision redness), and Apple Watch health data.

## Commands

### Secrets setup (required before first build)
```bash
cp .env.example .env.local      # then fill in your keys
./scripts/apply_env.sh          # generates DrinkingTracker/Secrets.swift (gitignored)
```
Re-run `apply_env.sh` whenever `.env.local` changes. Keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`, `VULTURE_SERVER_URL`.

### Generate & Open Xcode Project
```bash
xcodegen generate
open DrinkingTracker.xcodeproj
```
Must be re-run after modifying `project.yml` (adding files, changing targets, updating packages) **and** after dropping new `.swift` files into the folder — Xcode does not auto-detect them.

### Vulture ML Server
```bash
cd vulture-server
source venv/bin/activate
python main.py                    # starts on :8000
uvicorn main:app --reload         # alternative with hot-reload
```

Test the voice endpoint:
```bash
curl -X POST http://localhost:8000/analyze/voice -F "audio=@test.m4a"
```

```bash
cd vulture-server && pip install -r requirements.txt   # ~74 MB Whisper download on first run
```

## Architecture

### State Management
`AppState` (`DrinkingTracker/App/AppState.swift`) is the single source of truth, marked `@Observable` (iOS 17 macro). Injected at root via `.environment(appState)`, consumed with `@Environment(AppState.self)` in every view. Holds: Firebase user, session start time, BAC/stage, drink logs, analysis logs, health metrics, and all sheet-presentation booleans (`showAddDrink`, `showAnalysis`, etc.).

To get a `Binding` from `AppState` inside a view body, declare `@Bindable var state = appState` as a local variable.

### Navigation & Tab Structure
`RootView` (in `DrinkingTrackerApp.swift`) switches between `LoginView` and `DashboardView` based on `appState.isLoggedIn` (driven by Firebase auth state listener).

`DashboardView` (`Features/Dashboard/DashboardView.swift`) is the main tab container with 5 tabs:
- 0 `house` — Home (calendar + AI summary)
- 1 `martini.glass` — Session (live timer, drink counter, health metrics)
- 2 `calendar` — Habit Tracker (monthly calendar from real drink logs)
- 3 `bubble.left` — Gemini Chat
- 4 `camera` — Scan (face analysis)

The tab bar and all per-tab bottom action buttons live exclusively in `DashboardView`. Child tab views (`SessionView`, `HabitTrackerView`, `ScanView`) only render their scroll content — they do not own the tab bar. All sheets (`AddDrinkView`, `AnalysisView`, etc.) are presented from the root `DashboardView` level so any tab can trigger them via `appState` booleans.

### Design System
All colors, fonts, corner radii, and shadows are defined in `DrinkingTracker/AppTheme.swift`. Use `AppTheme.Colors.*`, `AppTheme.Fonts.mono()`, `AppTheme.Fonts.title()`, and the `.cardShadow()` view modifier — do not hardcode colors or fonts inline.

### Auth (`Features/Auth/LoginView.swift`)
Firebase Auth with three providers: email/password, Sign in with Apple (nonce + SHA256, `AuthenticationServices`), and Google Sign-In (`GoogleSignIn` SDK). The `LoginView` struct also handles sign-up (toggled inline) and password reset. `GoogleLogoView` is defined in this file.

### Data Flow
1. User adds a drink → `DrinkLogViewModel` saves to Supabase → inserts into `appState.drinkLogs` → `appState.refreshBAC()` recomputes via `BACCalculator.currentBAC(drinks:profile:)`
2. Session timer starts when "Start Drinking" is tapped → `appState.startSession()` → `AutoAnalysisTimer` fires every 15 min → `appState.showAnalysis = true`
3. Manual scan: `AnalysisViewModel` orchestrates the full pipeline — Watch data (WatchConnectivity), face photo (Vision), audio POST to Vulture server, Gemini summary, saves `AnalysisLog` to Supabase

### Services (all singletons via `.shared`)
- `SupabaseService` — wraps `supabase-swift` v2; all queries use `async/await` and `.execute().value` decoding
- `GeminiService` — `stageSummary()` for one-shot analysis, `startChat()`/`sendChatMessage()` for chatbot
- `VultureService` — multipart POST to FastAPI; returns `VultureResponse` with `transcript` + `slurScore`
- `HealthKitService` — reads last-hour HR, HRV, SpO2; call `refreshAll()` before analysis
- `WatchSessionManager` (iOS) — sends `"startCapture"` to watch, receives health dict + audio file

### iPhone ↔ Watch Communication
- iOS: `DrinkingTracker/Services/WatchSessionManager.swift`
- watchOS: `WatchApp/WatchSessionManager.swift` — records 60s audio + reads HealthKit, sends health dict via `sendMessage` and audio via `transferFile`
- BAC/stage synced to watch via `updateApplicationContext`

### Vulture Server
FastAPI at `vulture-server/main.py`. Pipeline in `routes/voice.py`:
1. `whisper_model.py` — lazy-loaded `openai-whisper` base model, returns transcript
2. `slur_detector.py` — scores on 4 heuristics → 0.0–1.0

### Database (Supabase)
Three tables: `user_profiles`, `drink_logs`, `analysis_logs`. Schema in `supabase/migrations/001_initial.sql`. All models use snake_case `CodingKeys`. Firebase UID is the `user_id` FK.

## Configuration

Credentials flow: `.env.local` → `scripts/apply_env.sh` → `DrinkingTracker/Secrets.swift` (gitignored) → `DrinkingTracker/Config.swift` (reads from `Secrets`).

`GoogleService-Info.plist` (from Firebase Console) must be manually dragged into the Xcode target after `xcodegen generate` — it is gitignored. The `REVERSED_CLIENT_ID` from this plist must also be set in `project.yml` under `CFBundleURLTypes` for Google Sign-In to work.

The Vulture server URL in `.env.local` must be the machine's LAN IP (not `localhost`) when running on a physical device.

## Key Constraints

- **`xcodegen generate` required** whenever new `.swift` files are added to the project folders — Xcode will silently omit them otherwise, causing "type not found" compile errors
- **Physical device required**: HealthKit, WatchConnectivity, and camera do not work in the Simulator
- **`@Observable` requires iOS 17+**: Do not use `ObservableObject`/`@Published` in the iPhone app; use `@Observable` and `@Bindable` instead
- **WatchApp uses `ObservableObject`**: Keep `WatchSessionManagerWatch` on `@Published`; `@Observable` support on watchOS may vary
- **Whisper model**: First call to `transcribe_audio()` downloads ~74 MB
