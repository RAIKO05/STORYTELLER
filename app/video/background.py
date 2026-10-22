import os
import random
import subprocess
from pathlib import Path
from typing import List, Dict, Optional
import yt_dlp

from app.config import BACKGROUNDS_DIR, VIDEO_WIDTH, VIDEO_HEIGHT

THEMATIC_QUERIES = {
    # 1. Gaming / High Retention
    "minecraft_parkour": {
        "name": "Minecraft Parkour (Vertical 9:16)",
        "category": "Gaming",
        "query": "ytsearch1:minecraft parkour gameplay no commentary vertical 9:16",
        "filename": "minecraft_parkour.mp4",
        "default_url": "https://www.youtube.com/watch?v=s600FYgI5-s"
    },
    "subway_surfers": {
        "name": "Subway Surfers Fast Run",
        "category": "Gaming",
        "query": "ytsearch1:subway surfers vertical gameplay no commentary copyright free",
        "filename": "subway_surfers.mp4",
        "default_url": "https://www.youtube.com/watch?v=hJcv2nZ8x84"
    },
    "gta_stunts": {
        "name": "GTA V Mega Ramp Stunts",
        "category": "Gaming",
        "query": "ytsearch1:gta 5 mega ramp vertical gameplay no commentary",
        "filename": "gta_stunts.mp4",
        "default_url": "https://www.youtube.com/watch?v=P3b3AidldmA"
    },
    "beamng_crashes": {
        "name": "BeamNG.drive Car Crashes & Stunts",
        "category": "Gaming",
        "query": "ytsearch1:beamng drive car crashes vertical no commentary 9:16",
        "filename": "beamng_crashes.mp4",
        "default_url": "https://www.youtube.com/watch?v=LkOvBURqSUg"
    },
    "roblox_obby": {
        "name": "Roblox Tower Obby Parkour",
        "category": "Gaming",
        "query": "ytsearch1:roblox obby gameplay vertical no commentary 9:16",
        "filename": "roblox_obby.mp4",
        "default_url": "https://www.youtube.com/watch?v=CVfvNKp_C8A"
    },
    "temple_run": {
        "name": "Temple Run 2 Classic Run",
        "category": "Gaming",
        "query": "ytsearch1:temple run 2 gameplay vertical no commentary",
        "filename": "temple_run.mp4",
        "default_url": "https://www.youtube.com/watch?v=fuQf-iGCmKA"
    },

    # 2. Satisfying / ASMR
    "satisfying_asmr": {
        "name": "Satisfying Kinetic Sand & Soap Cutting",
        "category": "Satisfying ASMR",
        "query": "ytsearch1:satisfying kinetic sand soap cutting vertical 9:16",
        "filename": "satisfying_asmr.mp4",
        "default_url": "https://www.youtube.com/watch?v=3clqk2U3T9Y"
    },
    "hydraulic_press": {
        "name": "Hydraulic Press ASMR Crushing",
        "category": "Satisfying ASMR",
        "query": "ytsearch1:satisfying hydraulic press crushing vertical 9:16",
        "filename": "hydraulic_press.mp4",
        "default_url": "https://www.youtube.com/watch?v=ZZh1m7gARhM"
    },
    "power_washing": {
        "name": "Oddly Satisfying Power Washing Cleaning",
        "category": "Satisfying ASMR",
        "query": "ytsearch1:satisfying power washing cleaning vertical 9:16",
        "filename": "power_washing.mp4",
        "default_url": "https://www.youtube.com/watch?v=3clqk2U3T9Y"
    },

    # 3. Aesthetic / Late Night / Driving
    "synthwave_drive": {
        "name": "Cyberpunk Synthwave Sunset Night Drive",
        "category": "Aesthetic",
        "query": "ytsearch1:synthwave sunset night drive loop vertical 9:16",
        "filename": "synthwave_drive.mp4",
        "default_url": "https://www.youtube.com/watch?v=7eTfyve4NXE"
    },

    # 4. Procedural AI Motion Backgrounds (100% Offline)
    "dark_cinematic": {
        "name": "Dark Atmospheric Mystery (AI Procedural)",
        "category": "AI Procedural",
        "query": "",
        "filename": "dark_cinematic.mp4",
        "default_url": ""
    },
    "neon_motion": {
        "name": "Neon Cyber Grid Motion (AI Procedural)",
        "category": "AI Procedural",
        "query": "",
        "filename": "neon_motion_loop.mp4",
        "default_url": ""
    },
    "aurora_galaxy": {
        "name": "Deep Space Galaxy & Aurora (AI Procedural)",
        "category": "AI Procedural",
        "query": "",
        "filename": "aurora_galaxy.mp4",
        "default_url": ""
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

        return self.generate_ai_procedural_background("neon_motion")

    def generate_ai_procedural_background(self, theme: str = "dark_cinematic") -> Path:
        """
        Procedurally generates an AI cinematic motion atmosphere background
        using rapid bilinear low-res synthesis without external downloads.
        """
        out_file = BACKGROUNDS_DIR / (THEMATIC_QUERIES.get(theme, {}).get("filename", f"{theme}.mp4"))
        if out_file.exists() and out_file.stat().st_size > 50000:
            return out_file

        print(f"[BackgroundManager] Generating procedural AI background: {theme}...")

        if theme == "dark_cinematic":
            vf = "scale=1080:1920:flags=bilinear,vignette=PI/3.2"
            cmd = [
                "ffmpeg", "-y",
                "-f", "lavfi",
                "-i", "gradients=s=270x480:d=45:c0=0x0a0f1d:c1=0x020408:speed=0.008",
                "-vf", vf,
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-pix_fmt", "yuv420p",
                "-t", "45",
                str(out_file)
            ]
        elif theme == "aurora_galaxy":
            vf = "scale=1080:1920:flags=bilinear,vignette=PI/3.5"
            cmd = [
                "ffmpeg", "-y",
                "-f", "lavfi",
                "-i", "gradients=s=270x480:d=45:c0=0x05192d:c1=0x003f5c:c2=0x2f4b7c:c3=0x665191:speed=0.01",
                "-vf", vf,
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-pix_fmt", "yuv420p",
                "-t", "45",
                str(out_file)
            ]
        else: # neon_motion
            vf = "scale=1080:1920:flags=bilinear,drawgrid=w=120:h=120:t=2:c=cyan@0.12"
            cmd = [
                "ffmpeg", "-y",
                "-f", "lavfi",
                "-i", "gradients=s=270x480:d=45:c0=0x150050:c1=0x000000:speed=0.015",
                "-vf", vf,
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-pix_fmt", "yuv420p",
                "-t", "45",
                str(out_file)
            ]

        try:
            subprocess.run(cmd, check=True, capture_output=True)
            return out_file
        except Exception as e:
            print(f"[BackgroundManager] Procedural generation warning: {e}")
            return out_file

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

        # Check if procedural theme
        if theme_data.get("category") == "AI Procedural":
            return self.generate_ai_procedural_background(theme_key)

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
                if theme_data.get("default_url"):
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
