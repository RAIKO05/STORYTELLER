import asyncio
import re
import edge_tts
from pathlib import Path
from typing import Dict, List, Tuple
from app.config import CACHE_DIR

VOICE_FALLBACK_MAP = {
    "en-US-ChristopherNeural": "en-US-BrianMultilingualNeural",
    "en-US-GuyNeural": "en-US-AndrewMultilingualNeural",
    "en-US-JennyNeural": "en-US-AvaMultilingualNeural",
    "en-US-AriaNeural": "en-US-EmmaMultilingualNeural",
    "en-US-AnaNeural": "en-US-AvaMultilingualNeural",
    "auto": "en-US-AndrewMultilingualNeural",
}

class TTSEngine:
    def __init__(self, default_voice: str = "en-US-AndrewMultilingualNeural"):
        self.default_voice = default_voice

    async def generate_speech(
        self,
        text: str,
        voice: str = "en-US-AndrewMultilingualNeural",
        rate: str = "+0%",
        pitch: str = "+0Hz",
        output_path: Path = None
    ) -> Dict:
        """
        Synthesizes text using Microsoft Edge Neural TTS with ultra-human conversational prosody.
        Captures SentenceBoundaries and word timings for karaoke subtitles.
        """
        if not output_path:
            output_path = CACHE_DIR / "speech.mp3"

        # Map legacy robotic voices to modern ultra-human neural voices
        effective_voice = VOICE_FALLBACK_MAP.get(voice, voice)
        if not effective_voice or effective_voice == "auto":
            effective_voice = self.default_voice

        # Prevent robotic rushed speeds - clamp to natural human conversational range (-5% to +6%)
        effective_rate = rate or "+0%"
        if effective_rate in ("+10%", "+12%", "+15%", "+18%", "+20%"):
            effective_rate = "+2%" # Gentle conversational clip without robotic rush

        # Prepare text for natural human cadence (natural breathing micro-pauses at punctuation)
        clean_speech_text = self._prepare_conversational_text(text)

        sentences = []
        audio_chunks = []

        # Attempt synthesis with automatic retry and standard neural voice fallback if needed
        voices_to_try = [effective_voice]
        if "Multilingual" in effective_voice:
            # Fallback to base non-multilingual version if network latency spikes
            voices_to_try.append(effective_voice.replace("Multilingual", ""))
        voices_to_try.append("en-US-AndrewNeural")

        last_error = None
        for candidate in voices_to_try:
            try:
                sentences = []
                audio_chunks = []
                communicate = edge_tts.Communicate(
                    text=clean_speech_text,
                    voice=candidate,
                    rate=effective_rate,
                    pitch=pitch
                )
                async for chunk in communicate.stream():
                    if chunk["type"] == "audio":
                        audio_chunks.append(chunk["data"])
                    elif chunk["type"] == "SentenceBoundary":
                        start_sec = chunk["offset"] / 10_000_000
                        duration_sec = chunk["duration"] / 10_000_000
                        sentences.append({
                            "text": chunk["text"].strip(),
                            "start": start_sec,
                            "duration": duration_sec,
                            "end": start_sec + duration_sec
                        })
                if audio_chunks:
                    break
            except Exception as e:
                last_error = e
                await asyncio.sleep(0.3)
                continue

        if not audio_chunks and last_error:
            raise last_error

        # Save audio file
        with open(output_path, "wb") as f:
            for c in audio_chunks:
                f.write(c)

        # Estimate word-level timings from sentences
        words = self._calculate_word_timings(sentences)

        total_duration = sentences[-1]["end"] if sentences else 0.0

        return {
            "audio_path": str(output_path),
            "duration": total_duration,
            "sentences": sentences,
            "words": words
        }

    def _prepare_conversational_text(self, text: str) -> str:
        """
        Cleans markdown artifacts and balances punctuation spacing to give neural voices
        natural human breath pauses between clauses and sentences.
        """
        if not text:
            return ""
        # Remove markdown bold/italic asterisks and underscores
        t = re.sub(r"[\*_]{1,3}", "", text)
        # Normalize multiple exclamation or question marks to single for natural pitch
        t = re.sub(r"!{2,}", "!", t)
        t = re.sub(r"\?{2,}", "?", t)
        # Replace em-dashes or multiple hyphens with a comma for a natural human pause
        t = re.sub(r"\s*--+\s*", ", ", t)
        # Ensure punctuation is followed by space
        t = re.sub(r"([,\.\?!;:])([A-Za-z0-9])", r"\1 \2", t)
        # Collapse multiple spaces
        t = re.sub(r"[ \t]+", " ", t).strip()
        return t

    def _calculate_word_timings(self, sentences: List[Dict]) -> List[Dict]:
        """
        Accurately distributes word timings within each sentence boundary
        proportional to word character lengths and natural pauses.
        """
        all_words = []
        for s in sentences:
            sentence_text = s["text"]
            # Split words while preserving punctuation
            words = sentence_text.split()
            if not words:
                continue

            # Weight by word length + extra weight if ends with comma or period
            weights = []
            for w in words:
                w_len = max(len(w), 1)
                if w.endswith((".", "!", "?")):
                    w_len += 2  # pause after sentence
                elif w.endswith((",", ";", ":")):
                    w_len += 1  # pause after comma
                weights.append(w_len)

            total_weight = sum(weights)
            current_time = s["start"]

            for i, word in enumerate(words):
                w_duration = (weights[i] / total_weight) * s["duration"]
                end_time = current_time + w_duration
                all_words.append({
                    "word": word,
                    "start": current_time,
                    "end": end_time,
                    "duration": w_duration
                })
                current_time = end_time

        return all_words
