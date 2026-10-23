import os
import time
import random
import subprocess
from pathlib import Path
from typing import Dict, Optional, Callable

from app.config import OUTPUTS_DIR, CACHE_DIR, AUDIO_DIR, VIDEO_WIDTH, VIDEO_HEIGHT
from app.utils.helpers import slugify
from app.video.tts import TTSEngine
from app.video.subtitles import SubtitleGenerator
from app.video.background import BackgroundManager
from app.scrapers.ai_generator import AIViralStoryGenerator

class VideoGenerator:
    def __init__(self):
        self.tts_engine = TTSEngine()
        self.subtitle_gen = SubtitleGenerator()
        self.bg_manager = BackgroundManager()
        self.ai_analyzer = AIViralStoryGenerator()

    async def generate_tiktok_video(
        self,
        title: str,
        story_text: str,
        voice: str = "auto",
        rate: str = "auto",
        pitch: str = "+0Hz",
        subtitle_style: str = "auto",
        highlight_color: str = "auto",
        font_name: str = "Arial Black",
        font_size: int = 70,
        margin_v: int = 650,
        text_case: str = "upper",
        background_id: Optional[str] = "auto",
        bg_music_id: Optional[str] = None,
        bg_music_volume: float = 0.15,
        voice_volume: float = 1.0,
        custom_bg_music_path: Optional[str] = None,
        status_callback: Optional[Callable[[str, int], None]] = None
    ) -> Dict:
        """
        Orchestrates full generation with AI Voice Matching, Audio Mixing & Auto-Scrubbed Background:
        1. AI Story Analysis (detects tone, picks best narrator, rate, background theme & colors)
        2. Auto-scrubs or preps vertical 9:16 background
        3. Generates TTS Speech & Timings without truncation
        4. Dynamic Karaoke Subtitles with custom typography
        5. Single-pass FFmpeg Assembly with optional background music mixing
        """
        timestamp = int(time.time())
        slug = slugify(title if title else "tiktok_story", max_length=25)
        job_id = f"{slug}_{timestamp}"
        
        job_cache_dir = CACHE_DIR / job_id
        job_cache_dir.mkdir(parents=True, exist_ok=True)
        
        audio_path = job_cache_dir / "voiceover.mp3"
        ass_path = job_cache_dir / "subtitles.ass"
        final_video_path = OUTPUTS_DIR / f"{job_id}.mp4"
        thumb_path = OUTPUTS_DIR / f"{job_id}_thumb.jpg"

        # Step 0: AI Story & Voice Analysis
        vibe_analysis = self.ai_analyzer.analyze_story_vibe(story_text, title)

        final_voice = vibe_analysis["recommended_voice"] if (voice == "auto" or not voice) else voice
        final_rate = vibe_analysis["recommended_rate"] if (rate == "auto" or not rate) else rate
        final_color = vibe_analysis["recommended_color"] if (highlight_color == "auto" or not highlight_color) else highlight_color
        final_style = vibe_analysis["subtitle_style"] if (subtitle_style == "auto" or not subtitle_style) else subtitle_style
        final_bg = vibe_analysis["recommended_bg"] if (background_id == "auto" or not background_id) else background_id

        if status_callback:
            status_callback(
                f"AI Matched: {vibe_analysis['vibe']} -> Voice: {vibe_analysis['voice_name']}, Speed: {final_rate}",
                10
            )

        # Step 1: TTS Generation (include title hook if not already in story)
        if status_callback:
            status_callback(f"Synthesizing voiceover with {final_voice} ({final_rate})...", 25)
        
        speakable_text = story_text.strip()
        clean_title = (title or "").strip()
        if clean_title and clean_title.lower() != "viral tiktok story" and not speakable_text.lower().startswith(clean_title.lower()):
            speakable_text = f"{clean_title}. {speakable_text}"

        tts_result = await self.tts_engine.generate_speech(
            text=speakable_text,
            voice=final_voice,
            rate=final_rate,
            pitch=pitch,
            output_path=audio_path
        )
        duration = tts_result["duration"]
        words = tts_result["words"]

        # Step 2: Generate Karaoke ASS Subtitles with custom typography
        if status_callback:
            status_callback("Generating dynamic karaoke subtitles...", 45)
            
        self.subtitle_gen.generate_ass(
            words=words,
            output_path=ass_path,
            style_mode=final_style,
            highlight_color=final_color,
            font_name=font_name,
            font_size=font_size,
            margin_v=margin_v,
            text_case=text_case
        )

        # Step 3: Scrub / Resolve Thematic Background
        if status_callback:
            status_callback(f"Scrubbing/Preparing 9:16 background ({final_bg})...", 65)

        bg_path = self.bg_manager.resolve_background_path(final_bg)
        source_dur = self.bg_manager.get_video_duration(str(bg_path))

        start_offset = 0.0
        if source_dur > duration + 5:
            max_start = int(source_dur - duration - 2)
            start_offset = random.randint(0, max(max_start, 1))

        # Step 4: Resolve Background Music
        resolved_bg_music_path = None
        if custom_bg_music_path and Path(custom_bg_music_path).exists():
            resolved_bg_music_path = Path(custom_bg_music_path)
        elif bg_music_id and bg_music_id != "none" and bg_music_id != "auto":
            for ext in [".m4a", ".mp3", ".wav"]:
                candidate = AUDIO_DIR / f"{bg_music_id}{ext}"
                if candidate.exists():
                    resolved_bg_music_path = candidate
                    break

        # Step 5: Single-Pass FFmpeg Assembly & Subtitle Burn-In
        if status_callback:
            status_callback("Encoding viral TikTok MP4 video in single-pass...", 80)

        escaped_ass = str(ass_path.resolve()).replace("\\", "/")
        escaped_ass = escaped_ass.replace(":", "\\:")

        vf_filter = (
            f"scale={VIDEO_WIDTH}:{VIDEO_HEIGHT}:force_original_aspect_ratio=increase,"
            f"crop={VIDEO_WIDTH}:{VIDEO_HEIGHT},"
            f"ass='{escaped_ass}'"
        )

        if resolved_bg_music_path:
            # Dual-input audio mix: Voiceover + Background Music
            filter_complex = (
                f"[0:v]{vf_filter}[vout];"
                f"[1:a]volume={voice_volume}[voice];"
                f"[2:a]volume={bg_music_volume}[bgm];"
                f"[voice][bgm]amix=inputs=2:duration=first:dropout_transition=2[aout]"
            )
            cmd = [
                "ffmpeg", "-y",
                "-stream_loop", "-1",
                "-ss", str(start_offset),
                "-i", str(bg_path),
                "-i", str(audio_path),
                "-stream_loop", "-1",
                "-i", str(resolved_bg_music_path),
                "-t", str(duration),
                "-filter_complex", filter_complex,
                "-map", "[vout]",
                "-map", "[aout]",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-c:a", "aac",
                "-b:a", "192k",
                "-pix_fmt", "yuv420p",
                str(final_video_path)
            ]
        else:
            cmd = [
                "ffmpeg", "-y",
                "-stream_loop", "-1",
                "-ss", str(start_offset),
                "-i", str(bg_path),
                "-i", str(audio_path),
                "-t", str(duration),
                "-vf", vf_filter,
                "-map", "0:v",
                "-map", "1:a",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-c:a", "aac",
                "-b:a", "192k",
                "-pix_fmt", "yuv420p",
                str(final_video_path)
            ]

        subprocess.run(cmd, check=True, capture_output=True)

        # Step 6: Generate Thumbnail
        try:
            thumb_cmd = [
                "ffmpeg", "-y",
                "-ss", "00:00:01.500",
                "-i", str(final_video_path),
                "-vframes", "1",
                "-q:v", "2",
                str(thumb_path)
            ]
            subprocess.run(thumb_cmd, check=True, capture_output=True)
        except Exception:
            pass

        if status_callback:
            status_callback("Complete! Video ready for TikTok & Shorts", 100)

        # Social Metadata
        safe_title = title.replace('"', '')
        tags_list = self.ai_generator.generate_viral_hashtags(title, story_text)
        hashtags = " ".join(tags_list)
        caption = f"{safe_title} 🤯 What would you do in this situation? Let me know in the comments! 👇\n\n{hashtags}"

        return {
            "job_id": job_id,
            "title": title,
            "duration": round(duration, 1),
            "video_path": str(final_video_path),
            "video_filename": final_video_path.name,
            "thumbnail_filename": thumb_path.name if thumb_path.exists() else None,
            "caption": caption,
            "hashtags": hashtags,
            "word_count": len(words),
            "ai_match": vibe_analysis
        }
