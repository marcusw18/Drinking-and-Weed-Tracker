# Google Cloud Run Deployment Guide

## Prerequisites

1. **Google Cloud Account** — https://cloud.google.com
2. **gcloud CLI** — https://cloud.google.com/sdk/docs/install
3. **Docker** (optional, Cloud Build handles it)

## Deployment Steps

### 1. Create a Google Cloud Project

```bash
# Set your project ID
export PROJECT_ID="drinking-tracker"
export REGION="us-central1"  # or your preferred region

# Create project
gcloud projects create $PROJECT_ID --name="Drinking Tracker Vulture Server"

# Set as default
gcloud config set project $PROJECT_ID
```

### 2. Enable Required APIs

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 3. Navigate to vulture-server

```bash
cd /path/to/vulture-server
```

### 4. Deploy to Cloud Run

```bash
gcloud run deploy vulture-ml-server \
  --source . \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 512Mi \
  --timeout 300
```

**Explanation:**
- `--source .` — Deploy from current directory (Cloud Build handles Docker)
- `--platform managed` — Use managed Cloud Run (serverless)
- `--region $REGION` — Deploy to specified region
- `--allow-unauthenticated` — Allow public access (required for iOS app)
- `--memory 512Mi` — Allocate 512MB RAM (sufficient for Whisper + FastAPI)
- `--timeout 300` — Allow 5 minutes for first request (Whisper download)

### 5. Get Your Public URL

After deployment completes (~2–3 minutes), you'll see:

```
Service [vulture-ml-server] revision [vulture-ml-server-001] has been deployed
and is serving 100 percent of traffic.
Service URL: https://vulture-ml-server-XXXXX-uc.a.run.app
```

### 6. Update iOS App

In [Config.swift](../DrinkingTracker/Config.swift}, update:

```swift
static let vultureServerURL = "https://vulture-ml-server-XXXXX-uc.a.run.app"
```

(Replace with your actual service URL)

---

## Testing Your Deployment

### Health Check
```bash
curl https://vulture-ml-server-XXXXX-uc.a.run.app/health
```

Expected:
```json
{"status":"ok"}
```

### Test Voice Analysis
```bash
curl -X POST https://vulture-ml-server-XXXXX-uc.a.run.app/analyze/voice \
  -F "audio=@test.m4a"
```

Expected:
```json
{
  "transcript": "...",
  "slur_score": 0.XXX
}
```

---

## Logs & Monitoring

### View Logs
```bash
gcloud run logs read vulture-ml-server --limit 50
```

### View in Google Cloud Console
https://console.cloud.google.com/run

---

## Important Notes

### Performance
- **First request:** ~30–45 seconds (Whisper downloads model ~74MB)
- **Subsequent requests:** <3 seconds
- **Concurrent requests:** Cloud Run auto-scales from 0 to 100+ instances

### Pricing (Cloud Run)
- **Always free tier:** 2M requests/month, 360K GB-seconds/month
- **Beyond free tier:** $0.40 per 1M requests + compute time
- Your team's usage will likely stay within free tier

### Cold Starts
- If no requests for 15+ minutes, instance shuts down
- Next request takes ~3–5 seconds to start (not counting Whisper)
- This is normal for serverless

### Instance Timeout
- Set to 300 seconds (5 minutes) to allow first Whisper download
- Subsequent requests ~1–2 seconds

---

## Redeployment (After Code Changes)

```bash
cd vulture-server
gcloud run deploy vulture-ml-server --source . --region $REGION
```

---

## Environment Variables (Optional)

If you need env vars, add to deployment:

```bash
gcloud run deploy vulture-ml-server \
  --source . \
  --region $REGION \
  --set-env-vars LOG_LEVEL=info,MODEL_SIZE=base
```

---

## Troubleshooting

### 403 Forbidden
Run: `--allow-unauthenticated` flag is required

### Connection Timeout
Likely Whisper downloading on first request. Wait 30–45 seconds.

### Container Build Fails
Check logs:
```bash
gcloud builds log --stream
```

Usually due to missing dependencies. Ensure `requirements.txt` is complete.

### Port Issues
Cloud Run uses port 8080 by default. The Dockerfile exposes 8080, and main.py respects the PORT env var.

---

## Summary

**Service URL:** `https://vulture-ml-server-[HASH]-[REGION].a.run.app`

**iOS App Config:**
```swift
static let vultureServerURL = "https://vulture-ml-server-[HASH]-[REGION].a.run.app"
```

**Endpoints:**
- `GET /health` → Status check
- `POST /analyze/voice` → Audio analysis

**Share with teammates:** Just the service URL! It's public and requires no auth.
