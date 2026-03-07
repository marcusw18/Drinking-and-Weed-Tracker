"""
Whisper-based audio transcription.
Uses openai-whisper running locally (no API key needed).

Model sizes: tiny, base, small, medium, large
- tiny:  fastest, least accurate (~39 MB)
- base:  good balance for hackathon (~74 MB)
- small: better accuracy (~244 MB)
"""
import whisper

_model = None


def _get_model(size: str = "base") -> whisper.Whisper:
    global _model
    if _model is None:
        _model = whisper.load_model(size)
    return _model


def transcribe_audio(file_path: str, model_size: str = "base") -> str:
    """
    Transcribe an audio file and return the text.
    Whisper handles m4a, mp3, wav, ogg, and more.
    """
    model = _get_model(model_size)
    result = model.transcribe(file_path, language="en", fp16=False)
    return result.get("text", "").strip()
