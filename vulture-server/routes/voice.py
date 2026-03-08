import tempfile
import os
from fastapi import APIRouter, UploadFile, File, HTTPException
from models.elevenlabs_model import transcribe_audio
from models.slur_detector import compute_slur_score

router = APIRouter()


@router.post("/voice")
async def analyze_voice(audio: UploadFile = File(...)):
    """
    Receive an audio file, transcribe it with ElevenLabs Speech-to-Text, and return a slur score.

    Returns:
        {
            "transcript": "...",
            "slur_score": 0.0–1.0
        }
    """
    if not audio.content_type or "audio" not in audio.content_type:
        raise HTTPException(status_code=400, detail="File must be an audio type.")

    # Save upload to a temp file
    suffix = os.path.splitext(audio.filename or "audio.m4a")[1] or ".m4a"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await audio.read())
        tmp_path = tmp.name

    try:
        transcript = transcribe_audio(tmp_path)
        slur_score = compute_slur_score(transcript)
    finally:
        os.unlink(tmp_path)

    return {
        "transcript": transcript,
        "slur_score": round(slur_score, 4),
    }
