"""
Slur / speech impairment detector.

Two-layer approach:
  1. Keyword heuristics: repeated words, filler words, nonsense patterns
  2. Phonetic features via edit-distance on common slurred word pairs

Returns a score 0.0 (no impairment) → 1.0 (severe impairment).
"""
import re
from difflib import SequenceMatcher

# Words that commonly get slurred
SLUR_PAIRS = [
    ("the", "duh"), ("what", "wha"), ("because", "cuz"),
    ("right", "rite"), ("really", "rilly"), ("something", "sumthin"),
    ("going", "goin"), ("nothing", "nuthin"), ("little", "lil"),
]

# Excessive filler words are a soft indicator
FILLER_WORDS = {"uh", "um", "like", "you know", "erm", "ah", "er"}


def compute_slur_score(transcript: str) -> float:
    """
    Analyse transcript text and return a slur score between 0.0 and 1.0.
    Higher = more impairment detected.
    """
    if not transcript:
        return 0.0

    text = transcript.lower()
    words = re.findall(r"\b\w+\b", text)
    total_words = max(len(words), 1)

    score_components: list[float] = []

    # 1. Repeated consecutive words (e.g. "I I I want")
    repetitions = sum(1 for i in range(1, len(words)) if words[i] == words[i - 1])
    repetition_score = min(repetitions / total_words * 5, 1.0)
    score_components.append(repetition_score)

    # 2. Filler word density
    filler_count = sum(1 for w in words if w in FILLER_WORDS)
    filler_score = min(filler_count / total_words * 3, 1.0)
    score_components.append(filler_score)

    # 3. Phonetic similarity to known slurred variants
    slur_hits = 0
    for word in words:
        for (clean, slurred) in SLUR_PAIRS:
            similarity = SequenceMatcher(None, word, slurred).ratio()
            if similarity > 0.75 and word != clean:
                slur_hits += 1
                break
    slur_score = min(slur_hits / total_words * 4, 1.0)
    score_components.append(slur_score)

    # 4. Sentence coherence proxy: very short sentences = possible impairment
    sentences = [s.strip() for s in re.split(r"[.!?]", text) if s.strip()]
    avg_sentence_length = total_words / max(len(sentences), 1)
    coherence_score = max(0.0, 1.0 - (avg_sentence_length / 10.0)) if avg_sentence_length < 5 else 0.0
    score_components.append(coherence_score)

    # Weighted average
    weights = [0.3, 0.2, 0.35, 0.15]
    final_score = sum(w * s for w, s in zip(weights, score_components))
    return round(min(final_score, 1.0), 4)
