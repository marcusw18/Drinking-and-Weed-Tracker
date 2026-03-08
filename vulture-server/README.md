# Vulture ML Server

AI-powered voice analysis for slur detection and intoxication assessment. Uses OpenAI Whisper for transcription and custom ML heuristics for slurring detection.

## Endpoints

- **GET `/health`** — Server health check
- **POST `/analyze/voice`** — Analyze audio for slurring

### POST /analyze/voice

**Request:**
```bash
curl -X POST http://localhost:8000/analyze/voice \
  -F "audio=@recording.m4a"
```

**Response:**
```json
{
  "transcript": "hello world",
  "slur_score": 0.25
}
```

## Local Development

### Setup

```bash
cd vulture-server
python3 -m venv venv
source venv/bin/activate  # or: venv\Scripts\activate (Windows)
pip install -r requirements.txt
```

### Run

```bash
python main.py
```

Server runs on `http://localhost:8000`

## Deployment to Vultr

Vultr is a cloud VPS provider. Deploy with Docker or native Python.

### Quick Start (Docker Recommended)

1. **Create Vultr Instance**
   - Go to https://www.vultr.com
   - Deploy server: Ubuntu 22.04 LTS with Docker
   - Copy your IP address (e.g., `203.0.113.45`)

2. **SSH into Server**
   ```bash
   ssh root@203.0.113.45
   ```

3. **Deploy**
   ```bash
   git clone https://github.com/marcusw18/Drinking-and-Weed-Tracker.git
   cd Drinking-and-Weed-Tracker/vulture-server
   docker-compose up -d
   ```

4. **Test**
   ```bash
   curl http://localhost:8000/health
   ```

5. **Update iOS App**
   ```swift
   static let vultureServerURL = "http://203.0.113.45:8000"
   ```

6. **Share with Teammates**
   ```
   Server URL: http://203.0.113.45:8000
   ```

For complete setup (native Python, Nginx, SSL), see [DEPLOYMENT_VULTR.md](DEPLOYMENT_VULTR.md).

## Environment Variables

- `PORT` — Server port (set by Render, default 8000)
- Future: Add rate limiting, API keys, etc.

## File Structure

```
vulture-server/
├── main.py              # FastAPI app
├── requirements.txt     # Python dependencies
├── Procfile            # Render deployment config
├── runtime.txt         # Python version
├── .gitignore          # Git ignore patterns
├── models/
│   ├── whisper_model.py
│   └── slur_detector.py
└── routes/
    └── voice.py
```

## Models

### Whisper (OpenAI)
- **Model:** base (74 MB)
- **Language:** English
- **Accuracy:** ~ 80–90% depending on audio quality

### Slur Detector
Custom ML approach using 4 heuristics:
1. **Repetition** — Consecutive word repetition
2. **Filler words** — "uh", "um", "like", etc.
3. **Phonetic similarity** — Common slurred word pairs
4. **Coherence** — Abnormally short sentences

Output: 0.0–1.0 score

## Troubleshooting

### 502 Bad Gateway
- Server is starting (waits for Whisper download on first request)
- Check Render logs: https://dashboard.render.com

### Audio file not accepted
- Must be `audio/*` MIME type
- Supported: m4a, mp3, wav, ogg, flac
- Max size: Check Render limits

### High latency on first request
- Expected: Whisper downloads model (~74MB) on first run
- Subsequent requests are fast
