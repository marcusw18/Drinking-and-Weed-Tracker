# Drinking Tracker

An iOS + Apple Watch harm-reduction app that tracks alcohol consumption, estimates BAC in real-time, and uses AI (Gemini + Whisper) to assess intoxication levels.

---

## Tech Stack

| Layer | Technology |
|---|---|
| iPhone App | SwiftUI (iOS 17+) |
| Apple Watch | SwiftUI (watchOS 10+) |
| Auth | Firebase Authentication |
| Database | Supabase (PostgreSQL) |
| AI Analysis | Google Gemini API |
| ML Server | Python FastAPI + OpenAI Whisper |
| Health Data | HealthKit + WatchConnectivity |
| Face Analysis | Apple Vision Framework (on-device) |

---

## Project Structure

```
DrinkingTracker/          # iOS App target
  App/                    # Entry point, global state
  Features/
    Auth/                 # Firebase login screen
    Dashboard/            # Main screen: BAC gauge, stage, health metrics, buttons
    DrinkLog/             # Add/view drink logs
    Analysis/             # Full analysis pipeline view
    Chatbot/              # Gemini chat interface
  Services/               # Supabase, Gemini, Vulture, HealthKit, WatchConnectivity
  Models/                 # DrinkLog, AnalysisLog, UserProfile, IntoxicationStage
  Utils/                  # BACCalculator, AutoAnalysisTimer
  Config.swift            # ← Fill in your API keys here

WatchApp/                 # watchOS App target
  WatchApp.swift
  WatchDashboardView.swift
  WatchSessionManager.swift  # Records voice + health, sends to iPhone

vulture-server/           # Python FastAPI ML server
  main.py
  routes/voice.py         # POST /analyze/voice
  models/whisper_model.py # Transcription
  models/slur_detector.py # Slur scoring

supabase/migrations/      # Run in Supabase SQL Editor
  001_initial.sql
```

---

## Setup

### 1. Firebase

1. Go to [Firebase Console](https://console.firebase.google.com) → New project
2. Add an **iOS app** with bundle ID `com.drinkingtracker.app`
3. Download `GoogleService-Info.plist` and add it to the **DrinkingTracker** Xcode target
4. Enable **Email/Password** under Authentication → Sign-in method

### 2. Supabase

1. Go to [Supabase](https://supabase.com) → New project
2. Open **SQL Editor** and run `supabase/migrations/001_initial.sql`
3. Copy **Project URL** and **anon key** from Settings → API

### 3. Gemini

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Create an API key

### 4. Fill in Config.swift

Open `DrinkingTracker/Config.swift` and fill in:
```swift
static let supabaseURL     = "https://YOUR_PROJECT.supabase.co"
static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
static let geminiAPIKey    = "YOUR_GEMINI_API_KEY"
static let vultureServerURL = "http://YOUR_SERVER_IP:8000"
```

### 5. Generate Xcode Project

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
```bash
brew install xcodegen
```

Generate the project:
```bash
cd "Drinking-and-Weed-Tracker"
xcodegen generate
open DrinkingTracker.xcodeproj
```

In Xcode:
- Set your **Development Team** on both targets (DrinkingTracker + DrinkingTrackerWatch)
- Add `GoogleService-Info.plist` to the DrinkingTracker target
- Build and run on a real device (HealthKit + Watch require physical hardware)

### 6. Vulture ML Server

```bash
cd vulture-server

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies (Whisper will download model on first run ~74MB)
pip install -r requirements.txt

# Start server
python main.py
# → Running at http://0.0.0.0:8000
```

Set `vultureServerURL` in `Config.swift` to your machine's local IP (e.g. `http://192.168.1.100:8000`) so the iPhone can reach it on the same network.

---

## Features

| Feature | Description |
|---|---|
| **Drink Logging** | Log drink type, %, volume → instant BAC update |
| **BAC Gauge** | Live arc gauge with decay over time (Widmark formula) |
| **Stage Visual** | 6-stage emoji + colour indicator with recommendations |
| **Health Metrics** | Heart rate, HRV, SpO2 from Apple Watch / HealthKit |
| **Auto Analysis** | Runs every 15 min during active session |
| **Manual Analysis** | Voice (Whisper slur detection) + face (Vision redness) + pre-survey |
| **Gemini Chat** | Ask harm-reduction questions based on your current state |
| **History** | Full drink log with per-day grouping + swipe to delete |

---

## BAC Formula

```
BAC = (grams_alcohol / (weight_kg × 1000 × r)) × 100 - (0.015 × hours)

r = 0.68 (male), 0.55 (female)
grams_alcohol = volume_ml × (ABV/100) × 0.789
```

## Intoxication Stages

| Stage | BAC | Label |
|---|---|---|
| 0 | < 0.03% | Sober |
| 1 | 0.03–0.08% | Relaxed |
| 2 | 0.08–0.15% | Tipsy |
| 3 | 0.15–0.25% | Drunk |
| 4 | 0.25–0.35% | Very Drunk |
| 5 | > 0.35% | Danger |
