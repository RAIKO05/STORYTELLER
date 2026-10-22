# 🎬 StoryTeller Pro - Viral TikTok Video Generator

A powerful, automated tool application that scrapes viral stories from **Reddit**, **Quora**, **YouTube transcripts**, or generates viral scripts with **AI**, then turns them into high-retention **9:16 vertical TikTok, YouTube Shorts, and Instagram Reels videos** with dynamic **CapCut / MrBeast-style karaoke captions** and background gameplay footage.

---

## 🌟 New: Fully AI-Matched Voice & Auto-Scrubbed Backgrounds

StoryTeller Pro now features an **AI Story & Voice Matcher** and **Thematic Background Auto-Scrubber**:
- 🤖 **AI Voice & Persona Matching**: Analyzes the narrative tone, perspective, and emotion to automatically choose the ideal narrator:
  - **Relationship & Wedding Drama / AITA**: Matched with `Jenny` (Conversational Female) or `Aria` (Emotional) at `+12%` pacing.
  - **Workplace Revenge & Malicious Compliance**: Matched with `Guy` (Energetic Narrator) at `+15%` pacing with Neon Lime highlights.
  - **Spooky, Horror & True Crime Mysteries**: Matched with `Eric` (Deep Mystery) at `+5%` pacing with Electric Cyan text.
  - **Chaos, Comedy & TIFU**: Matched with `Guy` / `Ana` at `+18%` pacing with high-velocity bouncing words.
  - **Late Night Confessions**: Matched with `Christopher` (Deep Storyteller) at `+8%` pacing.
- 🎮 **B-Roll Auto-Scrubber**: Automatically scrubs YouTube for copyright-free vertical 9:16 gameplay footage or generates procedural AI cinematic visuals matching the story theme:
  - `minecraft_parkour`: Minecraft Parkour Vertical 9:16 Gameplay
  - `subway_surfers`: Subway Surfers Fast Vertical Run
  - `gta_stunts`: GTA V Mega Ramp Stunts
  - `satisfying_asmr`: Satisfying Kinetic Sand / Soap Cutting ASMR
  - `dark_cinematic`: Procedural AI Atmospheric Mystery Loop

---

## ✨ Features

- **Multi-Source Story Ingestion**:
  - 🔥 **Reddit**: Scrapes top stories from `r/AmItheAsshole`, `r/tifu`, `r/confession`, `r/AskReddit`, `r/relationship_advice`, or parses any direct Reddit post link.
  - 💡 **Quora**: Scrapes viral Q&A secrets, life lessons, and confessions via search or direct link.
  - ▶️ **YouTube Transcripts**: Extracts subtitles & transcripts from any YouTube video URL using `yt-dlp` and formats them into a tight 60–90 second viral script.
  - ✨ **AI Scriptwriter**: Built-in viral storytelling engine (supports Google Gemini or rich offline algorithmic templates for revenge, moral dilemmas, and confessions).
  - ✍️ **Custom Story Editor**: Live word counter and estimated TikTok duration calculator.

- **Realistic Neural Voiceover (TTS)**:
  - Powered by **Microsoft Edge Neural TTS** (100% free, no API key required).
  - 7 top narrators: Christopher, Guy, Jenny, Aria, Ryan, Eric, and Ana.
  - Configurable pacing (`+10%`, `+18%`, `+25%`) for optimal TikTok retention.
  - Instant voice sample preview button.

- **Dynamic TikTok Karaoke Subtitles**:
  - Generates synchronized `.ass` (Advanced SubStation Alpha) subtitles with word-level highlight tracking.
  - Active word glows in **Neon Yellow (`#FFEE00`)**, **Neon Green**, **Cyan**, or **Hot Red**.
  - Formatted with thick black borders, drop shadows, and mobile-safe margins (positioned cleanly above TikTok's UI).

- **9:16 Vertical Video Studio**:
  - Auto-crops and scales background gameplay footage to 1080x1920.
  - Auto-scrubs or procedural AI motion loops.
  - Blazing fast single-pass FFmpeg encoding.

- **Social Media Metadata Generator**:
  - Automatically drafts viral titles, engaging descriptions, and trending hashtags (`#redditstories`, `#storytime`, `#fyp`, `#viral`).
  - One-click "Copy Caption & Hashtags" button.

---

## 🚀 Quick Start

### 1. Launch the Web Studio
Double-click `start.bat` or run:

```bash
python main.py
```

This will launch the local server and automatically open **`http://localhost:8000`** in your default web browser.

---

### 2. Command Line Interface (CLI)
You can also generate videos directly from your terminal:

```bash
# Full AI-Automated Generation (Auto-Matches voice and auto-scrubs background):
python cli.py --source ai --category revenge

# Generate from Reddit r/AmItheAsshole:
python cli.py --source reddit --subreddit AmItheAsshole

# Generate from a YouTube video transcript:
python cli.py --source youtube --url "https://www.youtube.com/watch?v=VIDEO_ID"

# Manually override voice or speed if desired:
python cli.py --source ai --category aita --voice en-US-ChristopherNeural --rate "+15%"
```

Generated videos are saved in the `outputs/` folder.
