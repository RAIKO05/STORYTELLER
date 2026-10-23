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

# TTS Voice Presets (Ultra-Human, Conversational & Expressive Narrators)
VOICE_PRESETS = [
    {"id": "en-US-AndrewMultilingualNeural", "name": "Andrew (Ultra-Human Storyteller Male - Viral TikTok & YouTube)", "gender": "Male", "lang": "en-US"},
    {"id": "en-US-AvaMultilingualNeural", "name": "Ava (Ultra-Human Female - Confessions & Emotional Drama)", "gender": "Female", "lang": "en-US"},
    {"id": "en-US-BrianMultilingualNeural", "name": "Brian (Deep Documentary & True Crime Male - Cinematic)", "gender": "Male", "lang": "en-US"},
    {"id": "en-US-EmmaMultilingualNeural", "name": "Emma (Expressive & Witty Female - Revenge & Drama)", "gender": "Female", "lang": "en-US"},
    {"id": "en-US-AndrewNeural", "name": "Andrew (Natural Conversational Male)", "gender": "Male", "lang": "en-US"},
    {"id": "en-US-AvaNeural", "name": "Ava (Natural Conversational Female)", "gender": "Female", "lang": "en-US"},
    {"id": "en-GB-RyanNeural", "name": "Ryan (Sophisticated British Storyteller)", "gender": "Male", "lang": "en-GB"},
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
