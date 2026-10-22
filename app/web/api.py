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
    CACHE_DIR
)
from app.scrapers.reddit import RedditScraper
from app.scrapers.quora import QuoraScraper
from app.scrapers.youtube import YouTubeScraper
from app.scrapers.ai_generator import AIViralStoryGenerator
from app.video.tts import TTSEngine
from app.video.background import BackgroundManager, THEMATIC_QUERIES
from app.video.generator import VideoGenerator

app = FastAPI(title="Viral TikTok Story Generator", version="2.2.0")

# Services
reddit_scraper = RedditScraper()
quora_scraper = QuoraScraper()
youtube_scraper = YouTubeScraper()
bg_manager = BackgroundManager()
video_gen = VideoGenerator()
tts_engine = TTSEngine()
ai_generator = AIViralStoryGenerator()

active_jobs = {}

# Mounts
app.mount("/outputs", StaticFiles(directory=str(OUTPUTS_DIR)), name="outputs")
app.mount("/static", StaticFiles(directory=str(Path(__file__).parent / "static")), name="static")

@app.get("/")
def read_root():
    return FileResponse(Path(__file__).parent / "static" / "index.html")

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

    return {
        "voices": voices,
        "subreddits": DEFAULT_SUBREDDITS,
        "backgrounds": bg_options,
        "preset_bg_downloads": list(THEMATIC_QUERIES.values()),
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

# ----------------- REDDIT -----------------
@app.get("/api/reddit/stories")
def get_reddit_stories(subreddit: str = "AmItheAsshole", query: str = ""):
    stories = reddit_scraper.search_reddit_stories(subreddit=subreddit, query=query)
    return {"status": "success", "subreddit": subreddit, "stories": stories}

class URLRequest(BaseModel):
    url: str

@app.post("/api/reddit/url")
def scrape_reddit_url(req: URLRequest):
    post = reddit_scraper.scrape_post_url(req.url)
    if not post:
        raise HTTPException(status_code=400, detail="Could not extract story from Reddit URL")
    return {"status": "success", "post": post}

# ----------------- QUORA -----------------
@app.get("/api/quora/stories")
def get_quora_stories(query: str = "viral secrets"):
    stories = quora_scraper.search_quora_stories(query=query)
    return {"status": "success", "stories": stories}

@app.post("/api/quora/url")
def scrape_quora_url(req: URLRequest):
    post = quora_scraper.scrape_url(req.url)
    if not post:
        raise HTTPException(status_code=400, detail="Could not extract story from Quora URL")
    return {"status": "success", "post": post}

# ----------------- YOUTUBE -----------------
@app.post("/api/youtube/transcript")
def get_youtube_transcript(req: URLRequest):
    data = youtube_scraper.fetch_video_transcript(req.url)
    if not data:
        raise HTTPException(status_code=400, detail="Could not retrieve transcript from YouTube video")
    return {"status": "success", "video": data}

# ----------------- AI STORY GENERATOR -----------------
class AIGenerateRequest(BaseModel):
    category: str = "aita"
    prompt: Optional[str] = ""
    duration: int = 60
    api_key: Optional[str] = None

@app.post("/api/ai/generate")
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
    snippet = " ".join(req.text.split()[:35])

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
    filename = file.filename.replace(" ", "_")
    target = BACKGROUNDS_DIR / filename
    with open(target, "wb") as f:
        f.write(await file.read())
    return {"status": "success", "filename": filename}

# ----------------- VIDEO GENERATION -----------------
class GenerateVideoRequest(BaseModel):
    title: str
    story: str
    voice: str = "auto"
    rate: str = "auto"
    pitch: str = "+0Hz"
    subtitle_style: str = "auto"
    highlight_color: str = "auto"
    background_id: Optional[str] = "auto"

@app.post("/api/video/generate")
async def generate_video(req: GenerateVideoRequest):
    if not req.story.strip():
        raise HTTPException(status_code=400, detail="Story text cannot be empty")

    job_id = f"job_{int(asyncio.get_event_loop().time() * 1000)}"
    active_jobs[job_id] = {"status": "Starting AI storytelling pipeline...", "percent": 5}

    def update_progress(msg: str, pct: int):
        active_jobs[job_id] = {"status": msg, "percent": pct}

    try:
        result = await video_gen.generate_tiktok_video(
            title=req.title,
            story_text=req.story,
            voice=req.voice,
            rate=req.rate,
            pitch=req.pitch,
            subtitle_style=req.subtitle_style,
            highlight_color=req.highlight_color,
            background_id=req.background_id,
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
