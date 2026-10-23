import json
import re
import requests
import yt_dlp
from typing import Optional, Dict
from app.utils.helpers import clean_text_for_tts

class YouTubeScraper:
    def __init__(self):
        self.ydl_opts = {
            "skip_download": True,
            "writesubtitles": True,
            "writeautomaticsub": True,
            "subtitleslangs": ["en.*", "en"],
            "quiet": True,
            "no_warnings": True
        }

    def fetch_video_transcript(self, url: str) -> Optional[Dict]:
        """
        Extracts title, author, metadata, and full transcript text from a YouTube video URL.
        """
        if not url:
            return None

        try:
            with yt_dlp.YoutubeDL(self.ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                title = info.get("title", "YouTube Story")
                channel = info.get("uploader", "Creator")
                duration = info.get("duration", 0)
                thumbnail = info.get("thumbnail", "")

                subs = info.get("subtitles", {}) or info.get("automatic_captions", {})
                
                # Look for English captions
                en_entries = subs.get("en", []) or subs.get("en-US", []) or subs.get("en-GB", [])
                if not en_entries:
                    # Check any key starting with 'en'
                    for key in subs.keys():
                        if key.startswith("en"):
                            en_entries = subs[key]
                            break

                transcript_text = ""
                # Try json3 format first, then vtt, srv3
                for fmt in en_entries:
                    fmt_ext = fmt.get("ext", "")
                    sub_url = fmt.get("url", "")
                    if not sub_url:
                        continue
                    
                    try:
                        r = requests.get(sub_url, timeout=10)
                        if r.status_code == 200:
                            if fmt_ext == "json3":
                                data = r.json()
                                lines = []
                                for event in data.get("events", []):
                                    for seg in event.get("segs", []):
                                        t = seg.get("utf8", "").strip()
                                        if t and t != "\n":
                                            lines.append(t)
                                transcript_text = " ".join(lines)
                                break
                            elif fmt_ext in ["vtt", "srv3", "ttml"]:
                                # Strip VTT timestamps and headers
                                clean_lines = []
                                for line in r.text.splitlines():
                                    line = line.strip()
                                    if not line or line.startswith("WEBVTT") or "-->" in line or line.isdigit():
                                        continue
                                    clean_lines.append(line)
                                transcript_text = " ".join(clean_lines)
                                break
                    except Exception as e:
                        print(f"[YouTubeScraper] Subtitle format fetch error: {e}")

                # If no transcripts available, use video description as narrative base
                if not transcript_text:
                    desc = info.get("description", "")
                    # Take first few meaningful lines
                    lines = [l.strip() for l in desc.splitlines() if len(l.strip()) > 30 and "http" not in l]
                    transcript_text = " ".join(lines[:6])

                cleaned_story = clean_text_for_tts(transcript_text)

                return {
                    "id": info.get("id", "yt_video"),
                    "title": title,
                    "channel": channel,
                    "duration_seconds": duration,
                    "thumbnail": thumbnail,
                    "story": cleaned_story
                }
        except Exception as e:
            print(f"[YouTubeScraper] Error fetching video: {e}")
            return None
