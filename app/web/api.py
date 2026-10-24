import os
import asyncio
from pathlib import Path
from typing import Optional, List
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel

from app.config import (
    VOICE_PRESETS,
    DEFAULT_SUBREDDITS,
    OUTPUTS_DIR,
    BACKGROUNDS_DIR,
    AUDIO_DIR,
    CACHE_DIR
)
from app.utils.helpers import get_local_ip
from app.scrapers.reddit import RedditScraper
from app.scrapers.quora import QuoraScraper
from app.scrapers.youtube import YouTubeScraper
from app.scrapers.ai_generator import AIViralStoryGenerator
from app.video.tts import TTSEngine
from app.video.background import BackgroundManager, THEMATIC_QUERIES
from app.video.generator import VideoGenerator
from app.security.shield import (
    SecurityShieldMiddleware,
    SecurityShield,
    generate_server_attestation,
    AUTHORIZED_BUNDLE_ID
)

app = FastAPI(title="Viral TikTok Story Generator", version="2.4.0")

# Security Hardening: Behavioral Firewall, Anti-Piracy Attestation & Anomaly Defense
app.add_middleware(SecurityShieldMiddleware)

# Services
reddit_scraper = RedditScraper()
quora_scraper = QuoraScraper()
youtube_scraper = YouTubeScraper()
bg_manager = BackgroundManager()
video_gen = VideoGenerator()
tts_engine = TTSEngine()
ai_generator = AIViralStoryGenerator()

import time
from collections import OrderedDict
from typing import Dict, Any

class ExpiringJobStore:
    """
    Bounded in-memory store for video generation job statuses with TTL eviction.
    Prevents heap memory exhaustion attacks and unbounded state leaks.
    """
    def __init__(self, max_entries: int = 500, ttl_seconds: int = 3600):
        self._store: OrderedDict[str, Dict[str, Any]] = OrderedDict()
        self.max_entries = max_entries
        self.ttl_seconds = ttl_seconds

    def _prune(self, now: float):
        expired = [k for k, v in self._store.items() if now - v.get("_updated_at", 0) > self.ttl_seconds]
        for k in expired:
            del self._store[k]

    def __setitem__(self, job_id: str, data: Dict[str, Any]):
        now = time.time()
        self._prune(now)
        data["_updated_at"] = now
        self._store[job_id] = data
        self._store.move_to_end(job_id)
        if len(self._store) > self.max_entries:
            self._store.popitem(last=False)

    def __getitem__(self, job_id: str) -> Dict[str, Any]:
        item = self._store.get(job_id)
        if item is None:
            raise KeyError(job_id)
        if time.time() - item.get("_updated_at", 0) > self.ttl_seconds:
            del self._store[job_id]
            raise KeyError(job_id)
        return item

    def __contains__(self, job_id: str) -> bool:
        if job_id not in self._store:
            return False
        if time.time() - self._store[job_id].get("_updated_at", 0) > self.ttl_seconds:
            del self._store[job_id]
            return False
        return True

    def get(self, job_id: str, default: Any = None) -> Any:
        try:
            return self[job_id]
        except KeyError:
            return default

active_jobs = ExpiringJobStore(max_entries=500, ttl_seconds=3600)

# Mounts
app.mount("/outputs", StaticFiles(directory=str(OUTPUTS_DIR)), name="outputs")
app.mount("/static", StaticFiles(directory=str(Path(__file__).parent / "static")), name="static")

@app.get("/")
def read_root():
    return FileResponse(
        Path(__file__).parent / "static" / "index.html",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0"
        }
    )

@app.get("/api/network-info")
def get_network_info():
    ip = get_local_ip()
    return {
        "status": "success",
        "local_ip": ip,
        "port": 8000,
        "iphone_url": f"http://{ip}:8000"
    }

class HandshakeRequest(BaseModel):
    bundle_id: str
    client_version: Optional[str] = "1.0.25"

@app.post("/api/security/handshake")
def security_handshake(req: HandshakeRequest):
    """
    Client/Server Attestation Handshake.
    Validates client authenticity and issues a cryptographic attestation token.
    """
    if req.bundle_id not in (AUTHORIZED_BUNDLE_ID, "com.storyteller.web"):
        raise HTTPException(
            status_code=403,
            detail=f"Integrity Violation: Unauthorized bundle ID '{req.bundle_id}' rejected."
        )
    headers = generate_server_attestation(req.bundle_id, "/api/security/handshake")
    return {
        "status": "success",
        "attestation": "verified",
        "authorized_bundle": req.bundle_id,
        "tokens": headers
    }

@app.get("/api/presets")
def get_presets():
    bg_options = [
        {"id": "auto", "name": "✨ AI Auto-Scrub (Matches story mood & intensity)", "category": "AI Smart", "size_mb": "Dynamic"}
    ]

    for key, data in THEMATIC_QUERIES.items():
        bg_options.append({
            "id": key,
            "name": data["name"],
            "category": data.get("category", "B-Roll"),
            "size_mb": "Auto-Scrub" if data.get("category") != "AI Procedural" else "Instant"
        })

    # Append any custom local files
    for local_bg in bg_manager.list_available_backgrounds():
        if local_bg["id"] not in [b["id"] for b in bg_options]:
            bg_options.append({
                "id": local_bg["id"],
                "name": local_bg["name"],
                "category": "Custom Local",
                "size_mb": f"{local_bg['size_mb']} MB"
            })

    voices = [
        {"id": "auto", "name": "✨ AI Auto-Select (Matches Story & Persona)", "gender": "AI", "lang": "en"}
    ] + VOICE_PRESETS

    bg_music = [
        {"id": "none", "name": "🔇 None (Narration Only)"},
        {"id": "cinematic_ambient", "name": "✨ Cinematic Ambient Glow (Soft Emotional Pad)"},
        {"id": "dramatic_suspense", "name": "⚡ Dramatic Suspense (Deep Tension Drone)"},
        {"id": "viral_pulse", "name": "🔥 Viral Synth Pulse (Energetic Rhythmic)"}
    ]

    fonts = [
        {"id": "Arial Black", "name": "Arial Black (High Impact Viral - Default)"},
        {"id": "Impact", "name": "Impact (Classic Meme & TikTok)"},
        {"id": "Trebuchet MS", "name": "Trebuchet MS (Modern Clean Bold)"},
        {"id": "Georgia", "name": "Georgia (Cinematic / Dramatic Mystery)"},
        {"id": "Comic Sans MS", "name": "Comic Sans MS (Playful Comedy)"}
    ]

    return {
        "voices": voices,
        "subreddits": DEFAULT_SUBREDDITS,
        "backgrounds": bg_options,
        "preset_bg_downloads": list(THEMATIC_QUERIES.values()),
        "bg_music": bg_music,
        "fonts": fonts,
        "subtitle_styles": [
            {"id": "auto", "name": "✨ AI Auto-Style (Pacing-Optimized)"},
            {"id": "karaoke", "name": "CapCut Karaoke (Word-by-word highlight)"},
            {"id": "single", "name": "MrBeast Bouncing Word (High velocity)"}
        ],
        "highlight_colors": [
            {"id": "auto", "name": "✨ AI Auto-Color (High Contrast)", "hex": "#00F2FE"},
            {"id": "&H00FFFF&", "name": "TikTok Yellow (Default)", "hex": "#FFEE00"},
            {"id": "&H00FF00&", "name": "Neon Lime Green", "hex": "#00FF44"},
            {"id": "&HFFFF00&", "name": "Electric Cyan", "hex": "#00E5FF"},
            {"id": "&H0000FF&", "name": "Hot Coral Red", "hex": "#FF3344"},
            {"id": "&H5BB1DF&", "name": "Imperial Amber Gold", "hex": "#DFB15B"},
            {"id": "&HFFFFFF&", "name": "Crisp Pure White", "hex": "#FFFFFF"}
        ]
    }

# ----------------- AI STORY ANALYSIS -----------------
class AnalyzeStoryRequest(BaseModel):
    story: str
    title: Optional[str] = ""

@app.post("/api/ai/analyze-story")
def analyze_story(req: AnalyzeStoryRequest):
    if not req.story.strip():
        raise HTTPException(status_code=400, detail="Story text is required for analysis")
    analysis = ai_generator.analyze_story_vibe(req.story, req.title or "")
    return {"status": "success", "analysis": analysis}

@app.post("/api/ai/hook-doctor")
def get_hook_doctor(req: AnalyzeStoryRequest):
    hooks = ai_generator.generate_viral_hooks(req.title or "", req.story or "")
    return {"status": "success", "hooks": hooks}

@app.post("/api/ai/split-story")
def get_split_story(req: AnalyzeStoryRequest):
    parts = ai_generator.split_story_into_parts(req.title or "", req.story or "")
    return {"status": "success", "parts": parts}

# ----------------- REDDIT -----------------
@app.get("/api/reddit/stories")
def get_reddit_stories(subreddit: str = "AmItheAsshole", query: str = ""):
    stories = reddit_scraper.search_reddit_stories(subreddit=subreddit, query=query)
    return {"status": "success", "subreddit": subreddit, "stories": stories}

class ScrapeURLRequest(BaseModel):
    url: str

@app.post("/api/reddit/scrape-url")
def scrape_reddit_url(req: ScrapeURLRequest):
    safe_url = SecurityShield.validate_url(req.url)
    post = reddit_scraper.scrape_post_url(safe_url)
    if not post:
        raise HTTPException(status_code=400, detail="Could not extract story from Reddit URL")
    return {"status": "success", "story": post}

# ----------------- QUORA -----------------
@app.get("/api/quora/stories")
def get_quora_stories(query: str = "viral secrets"):
    stories = quora_scraper.search_topics(query)
    return {"status": "success", "query": query, "stories": stories}

@app.post("/api/quora/scrape-url")
def scrape_quora_url(req: ScrapeURLRequest):
    safe_url = SecurityShield.validate_url(req.url)
    post = quora_scraper.scrape_url(safe_url)
    if not post:
        raise HTTPException(status_code=400, detail="Could not extract story from Quora URL")
    return {"status": "success", "story": post}

# ----------------- YOUTUBE -----------------
@app.post("/api/youtube/scrape")
def scrape_youtube(req: ScrapeURLRequest):
    safe_url = SecurityShield.validate_url(req.url)
    res = youtube_scraper.scrape_transcript(safe_url)
    if not res:
        raise HTTPException(status_code=400, detail="Could not extract transcript from YouTube URL")
    return {"status": "success", "data": res}

# ----------------- AI STORY WRITER -----------------
class AIGenerateRequest(BaseModel):
    category: str = "aita"
    prompt: Optional[str] = ""
    duration: int = 60
    api_key: Optional[str] = None

@app.post("/api/ai/generate-story")
def generate_ai_story(req: AIGenerateRequest):
    generator = AIViralStoryGenerator(api_key=req.api_key)
    story = generator.generate_story(
        category=req.category,
        prompt_hint=req.prompt,
        target_duration=req.duration
    )
    return {"status": "success", "result": story}

# ----------------- TTS PREVIEW -----------------
class TTSPreviewRequest(BaseModel):
    text: str
    voice: str = "auto"
    rate: str = "auto"
    pitch: str = "+0Hz"

@app.post("/api/tts/preview")
async def preview_tts(req: TTSPreviewRequest):
    preview_file = CACHE_DIR / "preview.mp3"
    words = req.text.strip().split() if req.text else []
    if len(words) < 5:
        snippet = "I never thought three years of keeping my mouth shut would end like this, but when she called the coordinator a murderer in front of two hundred guests, I lost all patience."
    else:
        snippet = " ".join(words[:40])

    final_voice = req.voice
    final_rate = req.rate
    if final_voice == "auto" or final_rate == "auto":
        analysis = ai_generator.analyze_story_vibe(req.text)
        if final_voice == "auto":
            final_voice = analysis["recommended_voice"]
        if final_rate == "auto":
            final_rate = analysis["recommended_rate"]

    res = await tts_engine.generate_speech(
        text=snippet,
        voice=final_voice,
        rate=final_rate,
        pitch=req.pitch,
        output_path=preview_file
    )
    return {
        "status": "success",
        "audio_url": "/api/tts/preview-audio",
        "voice_used": final_voice,
        "rate_used": final_rate,
        "duration": res["duration"]
    }

@app.get("/api/tts/preview-audio")
def get_preview_audio():
    preview_file = CACHE_DIR / "preview.mp3"
    if preview_file.exists():
        return FileResponse(preview_file, media_type="audio/mpeg")
    raise HTTPException(status_code=404, detail="Preview not found")

# ----------------- BACKGROUND SCRUB / UPLOAD -----------------
class BGScrubRequest(BaseModel):
    theme: str = "minecraft_parkour"

@app.post("/api/backgrounds/scrub")
def scrub_background(req: BGScrubRequest):
    path = bg_manager.scrub_thematic_background(req.theme)
    return {"status": "success", "theme": req.theme, "path": str(path)}

@app.post("/api/backgrounds/upload")
async def upload_background(file: UploadFile = File(...)):
    safe_filename = SecurityShield.sanitize_filename(file.filename, {".mp4", ".mov"})
    target = BACKGROUNDS_DIR / safe_filename
    content = await file.read()
    if len(content) > 150 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Background video file size exceeds 150MB limit.")
    with open(target, "wb") as f:
        f.write(content)
    return {"status": "success", "filename": safe_filename}

@app.post("/api/audio/upload")
async def upload_audio(file: UploadFile = File(...)):
    safe_filename = SecurityShield.sanitize_filename(file.filename, {".mp3", ".m4a", ".wav"})
    target = AUDIO_DIR / safe_filename
    content = await file.read()
    if len(content) > 50 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Audio file size exceeds 50MB limit.")
    with open(target, "wb") as f:
        f.write(content)
    return {"status": "success", "filename": safe_filename}

# ----------------- VIDEO GENERATION -----------------
class GenerateVideoRequest(BaseModel):
    title: str
    story: str
    voice: str = "auto"
    rate: str = "auto"
    pitch: str = "+0Hz"
    subtitle_style: str = "auto"
    highlight_color: str = "auto"
    font_name: str = "Arial Black"
    font_size: int = 70
    margin_v: int = 650
    text_case: str = "upper"
    background_id: Optional[str] = "auto"
    bg_music_id: Optional[str] = None
    bg_music_volume: float = 0.15
    voice_volume: float = 1.0
    custom_bg_music_filename: Optional[str] = None

@app.post("/api/video/generate")
async def generate_video(req: GenerateVideoRequest):
    # Context-Aware Input Guardrails
    clean_title, clean_story = SecurityShield.validate_story(req.title, req.story)

    job_id = f"job_{int(asyncio.get_event_loop().time() * 1000)}"
    active_jobs[job_id] = {"status": "Starting AI storytelling pipeline...", "percent": 5}

    def update_progress(msg: str, pct: int):
        active_jobs[job_id] = {"status": msg, "percent": pct}

    custom_music_path = None
    if req.custom_bg_music_filename:
        safe_music_file = SecurityShield.sanitize_filename(req.custom_bg_music_filename, {".mp3", ".m4a", ".wav"})
        cand = AUDIO_DIR / safe_music_file
        if cand.exists():
            custom_music_path = str(cand)

    try:
        result = await video_gen.generate_tiktok_video(
            title=clean_title,
            story_text=clean_story,
            voice=req.voice,
            rate=req.rate,
            pitch=req.pitch,
            subtitle_style=req.subtitle_style,
            highlight_color=req.highlight_color,
            font_name=req.font_name,
            font_size=req.font_size,
            margin_v=req.margin_v,
            text_case=req.text_case,
            background_id=req.background_id,
            bg_music_id=req.bg_music_id,
            bg_music_volume=req.bg_music_volume,
            voice_volume=req.voice_volume,
            custom_bg_music_path=custom_music_path,
            status_callback=update_progress
        )
        active_jobs[job_id] = {"status": "Done", "percent": 100, "result": result}
        return {"status": "success", "job_id": job_id, "data": result}
    except Exception as e:
        active_jobs[job_id] = {"status": f"Error: {str(e)}", "percent": -1}
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/video/status/{job_id}")
def get_job_status(job_id: str):
    if job_id not in active_jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    return active_jobs[job_id]

# ----------------- GALLERY -----------------
@app.get("/api/gallery")
def get_gallery():
    videos = []
    for f in OUTPUTS_DIR.glob("*.mp4"):
        thumb = f.with_name(f"{f.stem}_thumb.jpg")
        size_mb = round(f.stat().st_size / (1024 * 1024), 2)
        created_time = f.stat().st_mtime
        videos.append({
            "filename": f.name,
            "url": f"/outputs/{f.name}",
            "thumbnail_url": f"/outputs/{thumb.name}" if thumb.exists() else None,
            "size_mb": size_mb,
            "created_at": created_time
        })
    videos.sort(key=lambda x: x["created_at"], reverse=True)
    return {"status": "success", "videos": videos}

@app.delete("/api/gallery/{filename}")
def delete_gallery_video(filename: str):
    target = OUTPUTS_DIR / filename
    if not target.exists() or not target.is_file():
        raise HTTPException(status_code=404, detail="Video file not found")
    try:
        target.unlink()
        thumb = target.with_name(f"{target.stem}_thumb.jpg")
        if thumb.exists():
            thumb.unlink()
        return {"status": "success", "deleted": filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
