"""
ElevenLabs Speech-to-Text model.
Transcribes audio to text using ElevenLabs API.
"""
import os
from elevenlabs.client import ElevenLabs

# Initialize client
_client = None

# Hardcoded API key
ELEVENLABS_API_KEY = "e3879d5048a1246a19e7ebad57250cf80979d014cad07e7156f05fa037aaeaae"


def _get_client():
    """Get or initialize ElevenLabs client."""
    global _client
    if _client is None:
        api_key = os.getenv("ELEVENLABS_API_KEY", ELEVENLABS_API_KEY)
        if not api_key:
            raise ValueError("No API key available for ElevenLabs")
        _client = ElevenLabs(api_key=api_key)
    return _client


def transcribe_audio(file_path: str) -> str:
    """
    Transcribe an audio file to text using ElevenLabs Speech-to-Text.
    
    Supports: m4a, mp3, wav, ogg, flac, and other audio formats.
    
    Args:
        file_path: Path to audio file
        
    Returns:
        Transcribed text
        
    Raises:
        ValueError: If API key not set
        Exception: If transcription fails
    """
    client = _get_client()
    
    try:
        with open(file_path, "rb") as audio_file:
            transcript = client.speech_to_text.convert(
                audio=audio_file,
                language_code="en",  # English
            )
        
        return transcript["text"].strip() if transcript.get("text") else ""
    
    except FileNotFoundError:
        raise ValueError(f"Audio file not found: {file_path}")
    except Exception as e:
        raise Exception(f"ElevenLabs transcription error: {str(e)}")
