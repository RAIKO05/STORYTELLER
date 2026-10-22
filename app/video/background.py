import os
import random
import subprocess
from pathlib import Path
from typing import List, Dict, Optional
import yt_dlp

from app.config import BACKGROUNDS_DIR, VIDEO_WIDTH, VIDEO_HEIGHT

THEMATIC_QUERIES = {
    "minecraft_parkour": {
        "name": "Minecraft Parkour (Vertical)",
        "query": "ytsearch1:minecraft parkour gameplay no commentary vertical 9:16",
        "filename": "minecraft_parkour.mp4",
        "default_url": "https://www.youtube.com/watch?v=s600FYgI5-s"
    },
    "subway_surfers": {
        "name": "Subway Surfers (Vertical)",
        "query": "ytsearch1:subway surfers vertical gameplay no commentary copyright free",
        "filename": "subway_surfers.mp4",
        "default_url": "https://www.youtube.com/watch?v=hJcv2nZ8x84"
    },
    "gta_stunts": {
        "name": "GTA V Mega Ramp Stunts",
        "query": "ytsearch1:gta 5 mega ramp vertical gameplay no commentary",
        "filename": "gta_stunts.mp4",
        "default_url": "https://www.youtube.com/watch?v=P3b3AidldmA"
    },
    "satisfying_asmr": {
        "name": "Satisfying ASMR / Kinetic Sand",
        "query": "ytsearch1:satisfying kinetic sand soap cutting vertical 9:16",
        "filename": "satisfying_asmr.mp4",
        "default_url": "https://www.youtube.com/watch?v=3clqk2U3T9Y"
    },
    "dark_cinematic": {
        "name": "Dark Atmospheric Mystery",
        "query": "ytsearch1:dark aesthetic vertical video background copyright free",
        "filename": "dark_cinematic.mp4",
        "default_url": "https://www.youtube.com/watch?v=n_Dv4JMiwK8"
    }
}

class BackgroundManager:
    def __init__(self):
        BACKGROUNDS_DIR.mkdir(parents=True, exist_ok=True)
        self.ensure_default_background()

    def list_available_backgrounds(self) -> List[Dict]:
        """Lists all available video files in the backgrounds directory."""
        bg_files = []
        for f in BACKGROUNDS_DIR.glob("*.mp4"):
            size_mb = round(f.stat().st_size / (1024 * 1024), 2)
            bg_files.append({
                "id": f.stem,
                "name": f.stem.replace("_", " ").title(),
                "filename": f.name,
                "path": str(f),
                "size_mb": size_mb
            })
        return bg_files

    def ensure_default_background(self) -> Path:
        """
        Creates a fast, dynamic neon animated background using FFmpeg
        if no local background video exists yet.
        """
        default_file = BACKGROUNDS_DIR / "neon_motion_loop.mp4"
        if default_file.exists() and default_file.stat().st_size > 50000:
            return default_file

        print("[BackgroundManager] Generating procedural neon motion background...")
        cmd = [
            "ffmpeg", "-y",
            "-f", "lavfi",
            "-i", f"gradients=s={VIDEO_WIDTH}x{VIDEO_HEIGHT}:d=30:c0=0x150050:c1=0x000000:speed=0.015",
            "-vf", "noise=alls=10:allf=t+u,drawgrid=w=140:h=140:t=2:c=cyan@0.12",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-pix_fmt", "yuv420p",
            "-t", "30",
            str(default_file)
        ]
        try:
            subprocess.run(cmd, check=True, capture_output=True)
        except Exception as e:
            print(f"[BackgroundManager] Warning creating synthetic bg: {e}")

        return default_file

    def generate_ai_cinematic_background(self, theme: str = "dark_cinematic") -> Path:
        """
        Procedurally generates an AI cinematic motion atmosphere background
        without external downloads.
        """
        out_file = BACKGROUNDS_DIR / f"{theme}.mp4"
        if out_file.exists() and out_file.stat().st_size > 50000:
            return out_file

        vf = "drawbox=x=0:y=0:w=1080:h=1920:color=black@0.4:t=fill,vignette=PI/3"
        cmd = [
            "ffmpeg", "-y",
            "-f", "lavfi",
            "-i", f"gradients=s={VIDEO_WIDTH}x{VIDEO_HEIGHT}:d=45:c0=0x0a0f1d:c1=0x020408:speed=0.008",
            "-vf", vf,
            "-c:v", "libx264",
            "-preset", "fast",
            "-pix_fmt", "yuv420p",
            "-t", "45",
            str(out_file)
        ]

        try:
            subprocess.run(cmd, check=True, capture_output=True)
            return out_file
        except Exception:
            return self.ensure_default_background()

    def scrub_thematic_background(self, theme_key: str = "minecraft_parkour") -> Path:
        """
        Scrubs YouTube for royalty-free 9:16 vertical storytelling b-roll
        matching the theme, downloads a fast slice, and returns the path.
        """
        if theme_key not in THEMATIC_QUERIES:
            theme_key = "minecraft_parkour"

        theme_data = THEMATIC_QUERIES[theme_key]
        target_file = BACKGROUNDS_DIR / theme_data["filename"]

        if target_file.exists() and target_file.stat().st_size > 500000:
            return target_file

        if theme_key == "dark_cinematic":
            return self.generate_ai_cinematic_background("dark_cinematic")

        print(f"[BackgroundManager] Scrubbing YouTube for vertical b-roll: {theme_data['name']}...")
        search_query = theme_data["query"]

        ydl_opts = {
            "format": "bestvideo[height<=1080][ext=mp4]/best[ext=mp4]/best",
            "download_ranges": yt_dlp.utils.download_range_func(None, [(10, 90)]),
            "outtmpl": str(target_file),
            "quiet": True,
            "no_warnings": True,
            "socket_timeout": 15
        }

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([search_query])

            if target_file.exists() and target_file.stat().st_size > 500000:
                print(f"[BackgroundManager] Successfully scrubbed {theme_data['filename']} ({round(target_file.stat().st_size / (1024*1024), 1)} MB)")
                return target_file
        except Exception as e:
            print(f"[BackgroundManager] Scrub search failed: {e}. Trying direct fallback URL...")
            try:
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    ydl.download([theme_data["default_url"]])
                if target_file.exists() and target_file.stat().st_size > 500000:
                    return target_file
            except Exception as e2:
                print(f"[BackgroundManager] Fallback URL failed: {e2}")

        print("[BackgroundManager] Falling back to procedural AI motion background.")
        return self.ensure_default_background()

    def get_video_duration(self, video_path: str) -> float:
        """Gets exact video duration in seconds via ffprobe."""
        cmd = [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            video_path
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return float(res.stdout.strip())
        except Exception:
            return 30.0

    def resolve_background_path(self, bg_id_or_path: Optional[str]) -> Path:
        """
        Resolves or scrubs the background video file.
        """
        if bg_id_or_path:
            direct_p = Path(bg_id_or_path)
            if direct_p.exists():
                return direct_p
            
            named_p = BACKGROUNDS_DIR / f"{bg_id_or_path}.mp4"
            if named_p.exists() and named_p.stat().st_size > 50000:
                return named_p
            
            if bg_id_or_path in THEMATIC_QUERIES:
                return self.scrub_thematic_background(bg_id_or_path)

        return self.ensure_default_background()
