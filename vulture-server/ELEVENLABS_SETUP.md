# ElevenLabs Speech-to-Text Integration

Your Vulture server now uses **ElevenLabs Speech-to-Text** instead of Whisper for transcription.

## Setup

### 1. Create `.env` File (Local Development)

In `vulture-server/.env`:

```bash
ELEVENLABS_API_KEY=sk_2db8a7d9d0fc9b366390264b7dbf1a2e24fb6ae26f0c3849
```

**⚠️ Security:** Never commit `.env` to Git. It's in `.gitignore`.

### 2. Install Dependencies

```bash
cd vulture-server
pip install -r requirements.txt
```

**What changed:**
- Removed: `openai-whisper==20231117`
- Added: `elevenlabs==0.2.27`

### 3. Run Locally

```bash
# With environment variable set
export ELEVENLABS_API_KEY="your_api_key"
python main.py

# Or, create .env file and load it
python-dotenv run python main.py
```

### 4. Test

```bash
curl -X POST http://localhost:8000/analyze/voice \
  -F "audio=@test.m4a"
```

Expected response:
```json
{
  "transcript": "hello world",
  "slur_score": 0.05
}
```

---

## Deployment to Vultr / Cloud

### Environment Variable Setup

When deploying, set the environment variable in your platform:

**Vultr (via systemd):**
```bash
# In /etc/systemd/system/vulture-server.service
Environment="ELEVENLABS_API_KEY=sk_xxx"
```

**Docker Compose:**
```yaml
vulture-server:
  environment:
    - ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY}
```

**Cloud Run (Google Cloud):**
```bash
gcloud run deploy vulture-ml-server \
  --set-env-vars ELEVENLABS_API_KEY="sk_xxx"
```

**Railway / Render:**
- Add `ELEVENLABS_API_KEY` in the dashboard environment variables section

---

## Files Changed

| File | Change |
|------|--------|
| `requirements.txt` | Replaced Whisper with ElevenLabs SDK |
| `.env.example` | Added `ELEVENLABS_API_KEY` |
| `models/whisper_model.py` | Removed (deprecated) |
| `models/elevenlabs_model.py` | **NEW**: ElevenLabs transcription module |
| `routes/voice.py` | Updated import from Whisper → ElevenLabs |

---

## How It Works

### Pipeline

```
Audio File (m4a, mp3, wav, etc.)
    ↓
ElevenLabs Speech-to-Text API
    ↓
Transcript (text)
    ↓
Slur Detector (custom heuristics)
    ↓
Slur Score (0.0–1.0)
```

### ElevenLabs API Call

```python
from elevenlabs.client import ElevenLabs

client = ElevenLabs(api_key="sk_xxx")
result = client.speech_to_text.convert(
    audio=open("audio.m4a", "rb"),
    language_code="en"
)
transcript = result["text"]
```

---

## Performance

| Metric | Details |
|--------|---------|
| **Latency** | 1–5 seconds (depends on audio length & ElevenLabs load) |
| **Cost** | Billed per minute of audio processed |
| **Accuracy** | ~95% for English speech (better than Whisper) |
| **Concurrent Requests** | ElevenLabs limits based on plan |

---

## API Key Management

### Keep it Secure

✅ **DO:**
- Store in `.env` file (gitignored)
- Use environment variables in production
- Rotate key periodically

❌ **DON'T:**
- Commit to Git
- Share in plain text
- Hardcode in source files

### Regenerate Key

If compromised:
1. Go to https://elevenlabs.io/app/settings/api
2. Click regenerate
3. Update `.env` and deployment configs immediately

---

## Troubleshooting

### "ELEVENLABS_API_KEY not set"

**Fix:** Ensure the environment variable is set before running:

```bash
export ELEVENLABS_API_KEY="sk_xxx"
python main.py
```

### "Transcription failed"

Check:
1. Audio file is valid (test with another tool)
2. API key has "Speech to Text" permission enabled
3. ElevenLabs API status: https://status.elevenlabs.io

### "401 Unauthorized"

- API key is invalid or expired
- Check the key at https://elevenlabs.io/app/settings/api
- Regenerate if needed

---

## Next Steps

1. **Create `.env` file with your API key**
2. **Test locally:** `python main.py`
3. **Deploy to Vultr/Cloud with environment variable set**
4. **Update iOS app to point to your server**
5. **Share the server URL with teammates**

---

## Costs

ElevenLabs pricing for Speech-to-Text:
- **Creator Plan:** $11/month + overage charges
- **Professional:** $99/month + overage charges
- **Enterprise:** Custom pricing

Check your plan at: https://elevenlabs.io/app/billing/overview
