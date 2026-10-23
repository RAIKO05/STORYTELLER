import os
import time
import random
import subprocess
from pathlib import Path
from typing import Dict, Optional, Callable

from app.config import OUTPUTS_DIR, CACHE_DIR, VIDEO_WIDTH, VIDEO_HEIGHT
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
        background_id: Optional[str] = "auto",
        bg_music_id: Optional[str] = None,
        status_callback: Optional[Callable[[str, int], None]] = None
    ) -> Dict:
        """
        Orchestrates full generation with AI Voice Matching & Auto-Scrubbing Background:
        1. AI Story Analysis (detects tone, picks best narrator, rate, background theme & colors)
        2. Auto-scrubs or preps vertical 9:16 background
        3. Generates TTS Speech & Timings
        4. Dynamic Karaoke Subtitles
        5. Blazing-fast Single-pass FFmpeg Assembly
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

        # Step 2: Generate Karaoke ASS Subtitles
        if status_callback:
            status_callback("Generating dynamic karaoke subtitles...", 45)
            
        self.subtitle_gen.generate_ass(
            words=words,
            output_path=ass_path,
            style_mode=final_style,
            highlight_color=final_color
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

        # Step 4: Single-Pass FFmpeg Assembly & Subtitle Burn-In
        if status_callback:
            status_callback("Encoding viral TikTok MP4 video in single-pass...", 80)

        escaped_ass = str(ass_path.resolve()).replace("\\", "/")
        escaped_ass = escaped_ass.replace(":", "\\:")

        vf_filter = (
            f"scale={VIDEO_WIDTH}:{VIDEO_HEIGHT}:force_original_aspect_ratio=increase,"
            f"crop={VIDEO_WIDTH}:{VIDEO_HEIGHT},"
            f"ass='{escaped_ass}'"
        )

        cmd = [
            "ffmpeg", "-y",
            "-stream_loop", "-1",
            "-ss", str(start_offset),
            "-i", str(bg_path),
            "-i", str(audio_path),
            "-t", str(duration),
            "-vf", vf_filter,
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-c:a", "aac",
            "-b:a", "192k",
            "-pix_fmt", "yuv420p",
            str(final_video_path)
        ]

        subprocess.run(cmd, check=True, capture_output=True)

        # Step 5: Generate Thumbnail
        try:
            thumb_cmd = [
                "ffmpeg", "-y",
                "-ss", "00:00:01.500",
                "-i", str(final_video_path),
                "-vframes", "1",
                "-q:v", "2",
                str(thumb_path)
            ]
            subprocess.run(thumb_cmd, capture_output=True)
        except Exception:
            pass

        if status_callback:
            status_callback("Video generation completed!", 100)

        # Generate viral TikTok hashtags & caption
        category_tag = f"#{vibe_analysis['vibe_key']}story"
        hashtags = f"#redditstories #storytime #fyp #viral #foryou #askreddit {category_tag} #dailyvibes"
        tiktok_caption = f"{title}\n\nWhat would you do? Drop your thoughts below 👇\n\n{hashtags}"

        return {
            "job_id": job_id,
            "title": title,
            "duration": round(duration, 1),
            "video_path": str(final_video_path),
            "video_filename": final_video_path.name,
            "thumbnail_filename": thumb_path.name if thumb_path.exists() else None,
            "caption": tiktok_caption,
            "hashtags": hashtags,
            "word_count": len(words),
            "ai_match": {
                "vibe": vibe_analysis["vibe"],
                "voice": final_voice,
                "voice_name": vibe_analysis["voice_name"],
                "rate": final_rate,
                "background": final_bg,
                "bg_name": vibe_analysis["bg_name"],
                "color": final_color,
                "rationale": vibe_analysis["rationale"]
            }
        }
