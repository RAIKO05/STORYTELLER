import os
import sys
import socket
import webbrowser
import threading
import time
import uvicorn

from app.config import (
    BASE_DIR,
    OUTPUTS_DIR,
    BACKGROUNDS_DIR,
    AUDIO_DIR
)
from app.video.background import BackgroundManager

def get_local_ip() -> str:
    """Retrieve local Wi-Fi / LAN IP address for iPhone connection."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def open_browser():
    """Auto open browser once the server starts."""
    time.sleep(1.5)
    url = "http://localhost:8000"
    print(f"\n[StoryTeller] Opening Web App at: {url}\n")
    webbrowser.open(url)

def main():
    local_ip = get_local_ip()

    print("=" * 65)
    print("  🎬 STORYTELLER PRO - UNIVERSAL PC & IPHONE STUDIO")
    print("=" * 65)
    print(f"[*] Workspace Root:    {BASE_DIR}")
    print(f"[*] PC Web Access:     http://localhost:8000")
    print(f"[*] 📲 iPhone Access:  http://{local_ip}:8000")
    print("=" * 65)
    
    # Initialize background generator
    bg_mgr = BackgroundManager()
    bg_mgr.ensure_default_background()
    print("[*] Background footage initialized.")

    # Start browser in background thread
    threading.Thread(target=open_browser, daemon=True).start()

    # Run FastAPI web server binding to 0.0.0.0 so iPhone can connect over Wi-Fi
    uvicorn.run(
        "app.web.api:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )

if __name__ == "__main__":
    main()
