import os
from pathlib import Path

# Base Paths
BASE_DIR = Path(__file__).resolve().parent.parent
APP_DIR = BASE_DIR / "app"
ASSETS_DIR = BASE_DIR / "assets"
BACKGROUNDS_DIR = ASSETS_DIR / "backgrounds"
AUDIO_DIR = ASSETS_DIR / "audio"
FONTS_DIR = ASSETS_DIR / "fonts"
OUTPUTS_DIR = BASE_DIR / "outputs"
CACHE_DIR = BASE_DIR / ".cache"

# Ensure directories exist
for p in [BACKGROUNDS_DIR, AUDIO_DIR, FONTS_DIR, OUTPUTS_DIR, CACHE_DIR]:
    p.mkdir(parents=True, exist_ok=True)

# TTS Voice Presets (Popular TikTok / Reels Narrators)
VOICE_PRESETS = [
    {"id": "en-US-ChristopherNeural", "name": "Christopher (Storyteller Male - Deep & Cinematic)", "gender": "Male", "lang": "en-US"},
    {"id": "en-US-GuyNeural", "name": "Guy (Energetic Viral Narrator)", "gender": "Male", "lang": "en-US"},
    {"id": "en-US-JennyNeural", "name": "Jenny (Natural Conversational Female)", "gender": "Female", "lang": "en-US"},
    {"id": "en-US-AriaNeural", "name": "Aria (Dramatic / Emotional Female)", "gender": "Female", "lang": "en-US"},
    {"id": "en-GB-RyanNeural", "name": "Ryan (British Narration)", "gender": "Male", "lang": "en-GB"},
    {"id": "en-US-EricNeural", "name": "Eric (Serious / True Crime Mystery)", "gender": "Male", "lang": "en-US"},
    {"id": "en-US-AnaNeural", "name": "Ana (Youthful / Upbeat Female)", "gender": "Female", "lang": "en-US"},
]

# Popular Subreddits for viral stories
DEFAULT_SUBREDDITS = [
    {"id": "AmItheAsshole", "name": "r/AmItheAsshole (AITA Moral Dilemmas)"},
    {"id": "tifu", "name": "r/tifu (Today I Screwed Up - Comedy & Chaos)"},
    {"id": "confession", "name": "r/confession (Deep Dark Confessions)"},
    {"id": "TrueOffMyChest", "name": "r/TrueOffMyChest (Venting & Revelations)"},
    {"id": "AskReddit", "name": "r/AskReddit (Wildest Real Life Stories)"},
    {"id": "relationship_advice", "name": "r/relationship_advice (Infidelity & Drama)"},
    {"id": "maliciouscompliance", "name": "r/maliciouscompliance (Epic Revenge)"},
]

# Video Dimensions for 9:16 vertical TikTok/Shorts
VIDEO_WIDTH = 1080
VIDEO_HEIGHT = 1920
DEFAULT_FPS = 30
