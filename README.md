# 🎬 StoryTeller Pro - Universal Studio (PC & iPhone)

A unified **viral TikTok & Shorts video generator** designed to work seamlessly across your **PC** and **iPhone**.

---

## 📱 Universal Architecture (PC + iPhone Synergy)

```
       +---------------------------------------------+
       |           PC Backend & Video Engine         |
       |  (FastAPI + FFmpeg + Edge-TTS + Scrapers)   |
       |             LAN: 192.168.11.146:8000        |
       +----------------------+----------------------+
                              |
                     Local Wi-Fi Network
                              |
       +----------------------+----------------------+
       |          StoryTeller iOS App (.ipa)          |
       |  (Native SwiftUI + AVPlayer + Photos Save)  |
       |      Installed via Sideloadly / AltStore    |
       +---------------------------------------------+
```

1. **PC**: Runs the heavy rendering engine (`FFmpeg`, `Edge Neural TTS`, and video scraper).
2. **iPhone**: A native iOS SwiftUI client (`StoryTeller.ipa`):
   - Browse & scrape viral stories from Reddit, Quora, YouTube transcripts, or AI.
   - **AI Story & Voice Matcher**: Automatically picks the best voice, speed, and b-roll.
   - **Live 9:16 Video Player**: Watch rendered videos directly on your phone.
   - **1-Tap Save to Camera Roll (`PHPhotoLibrary`)**: Downloads the MP4 directly into your iPhone Photos app so you can immediately post to **TikTok**, **Instagram Reels**, or **YouTube Shorts**!
   - **One-Tap Caption Copy**: Copies viral titles and hashtags to clipboard.

---

## 🛠️ How to Build & Download `StoryTeller.ipa` via GitHub Actions

Just like in the **Bayan** project, StoryTeller includes an automated cloud Mac build workflow [`.github/workflows/build-ios.yml`](.github/workflows/build-ios.yml) powered by **XcodeGen**:

### Step 1: Push to your GitHub Repository
Create a new GitHub repository (e.g. `STORYTELLER`) on your GitHub account (`RAIKO05`), then run in terminal:

```bash
cd "c:\Users\Aka.mouadd\STORY TELLER"
git remote add origin https://github.com/RAIKO05/STORYTELLER.git
git push -u origin main
```

### Step 2: Automated Cloud Mac Build
1. GitHub Actions will automatically start the **Build iOS App on Cloud Mac** workflow (`macos-15`).
2. It installs XcodeGen, generates the Xcode project, compiles the iOS app, and packages `StoryTeller.ipa`.
3. Within ~2–3 minutes, your **`StoryTeller.ipa`** will be published and available for direct download in:
   - **GitHub Actions Artifacts** (under Summary > `StoryTeller-iOS-App`)
   - **GitHub Releases** (under Releases > `v1.0.x`)

### Step 3: Install on iPhone
Install `StoryTeller.ipa` onto your iPhone using your preferred sideloading tool:
- **AltStore / AltServer** (Windows or Mac)
- **Sideloadly** (1-click USB/Wi-Fi installer)
- **TrollStore** (if iOS 14.0–17.0)
- **Scarlet** or **Esig**

---

## 📲 Connecting iPhone to your PC

1. **Start the PC Server**:
   ```bash
   python main.py
   ```
   *Your PC will display its local Wi-Fi address (e.g., `http://192.168.11.146:8000`).*

2. **Open the StoryTeller iOS App**:
   - Ensure your iPhone is connected to the same Wi-Fi network.
   - Open the **Connect** tab in the app.
   - Tap **Local Wi-Fi PC (`http://192.168.11.146:8000`)** or enter your PC's IP.
   - Tap **Test**. The status dot turns **Green (Connected)**.

3. **Generate & Post**:
   - Pick a Reddit, Quora, YouTube, or AI story.
   - The AI automatically recommends the narrator voice, pacing, and B-Roll footage.
   - Tap **GENERATE VIRAL TIKTOK VIDEO**.
   - Watch the video in the native 9:16 player.
   - Tap **Save to iPhone Photos (Camera Roll)**.
   - Open TikTok or Reels and upload directly from your Photos!

---

## 📁 Repository Structure

```
STORY TELLER/
├── .github/
│   └── workflows/
│       └── build-ios.yml      # GitHub Actions cloud compiler for StoryTeller.ipa
├── ios/
│   ├── project.yml            # XcodeGen project specification (iOS 17.0+)
│   ├── StoryTellerApp.swift   # iOS App entry point
│   ├── Config/
│   │   ├── Info.plist         # Photos permission & LAN arbitrary loads
│   │   └── StoryTeller.entitlements
│   ├── Models/
│   │   └── StoryModel.swift   # Swift Codable data models
│   ├── Services/
│   │   └── StoryTellerAPIService.swift # REST client & Camera Roll exporter
│   ├── Views/
│   │   ├── MainTabView.swift
│   │   ├── CreatorView.swift  # Native SwiftUI Studio with AI Matcher
│   │   ├── VideoPlayerSheet.swift # 9:16 Video Player & Photos Saver
│   │   ├── GalleryView.swift  # Video Vault
│   │   ├── ServerConnectSheet.swift # Wi-Fi IP configuration
│   │   └── StoryTellerWebView.swift # Embedded Web Studio
│   └── Assets.xcassets/       # AppIcon & AccentColor
├── app/                       # Python FastAPI + Scrapers + Video Engine
├── assets/                    # Backgrounds & Audio
├── outputs/                   # Rendered 1080x1920 MP4 videos
├── main.py                    # Multi-interface server (PC & iPhone LAN)
├── cli.py                     # CLI generator
└── start.bat                  # One-click Windows starter
```
