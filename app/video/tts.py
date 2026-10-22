import asyncio
import edge_tts
from pathlib import Path
from typing import Dict, List, Tuple
from app.config import CACHE_DIR

class TTSEngine:
    def __init__(self, default_voice: str = "en-US-ChristopherNeural"):
        self.default_voice = default_voice

    async def generate_speech(
        self,
        text: str,
        voice: str = "en-US-ChristopherNeural",
        rate: str = "+10%",
        pitch: str = "+0Hz",
        output_path: Path = None
    ) -> Dict:
        """
        Synthesizes text using Microsoft Edge Neural TTS.
        Captures SentenceBoundaries and word timings for karaoke subtitles.
        """
        if not output_path:
            output_path = CACHE_DIR / "speech.mp3"

        communicate = edge_tts.Communicate(
            text=text,
            voice=voice,
            rate=rate,
            pitch=pitch
        )

        sentences = []
        audio_chunks = []

        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_chunks.append(chunk["data"])
            elif chunk["type"] == "SentenceBoundary":
                # offset and duration are in 100ns units (ticks)
                start_sec = chunk["offset"] / 10_000_000
                duration_sec = chunk["duration"] / 10_000_000
                sentences.append({
                    "text": chunk["text"].strip(),
                    "start": start_sec,
                    "duration": duration_sec,
                    "end": start_sec + duration_sec
                })

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
