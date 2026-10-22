document.addEventListener("DOMContentLoaded", () => {
    // State
    let presets = null;
    let latestAnalysis = null;
    let analyzeTimeout = null;

    // Elements
    const wordCounter = document.getElementById("word-counter");
    const storyTitleInput = document.getElementById("story-title");
    const storyTextInput = document.getElementById("story-text");

    const voiceSelect = document.getElementById("voice-select");
    const rateSelect = document.getElementById("rate-select");
    const bgSelect = document.getElementById("background-select");
    const subStyleSelect = document.getElementById("subtitle-style-select");
    const colorSelect = document.getElementById("color-select");

    const aiVibeBox = document.getElementById("ai-vibe-box");
    const vibeTitle = document.getElementById("vibe-title");
    const vibeRationale = document.getElementById("vibe-rationale");
    const vibeTagTone = document.getElementById("vibe-tag-tone");
    const vibeTagVoice = document.getElementById("vibe-tag-voice");
    const vibeTagBg = document.getElementById("vibe-tag-bg");
    const vibeTagSpeed = document.getElementById("vibe-tag-speed");
    const btnApplyVibe = document.getElementById("btn-apply-vibe");

    const btnGenerateVideo = document.getElementById("btn-generate-video");
    const renderProgressBox = document.getElementById("render-progress-box");
    const renderProgressFill = document.getElementById("render-progress-fill");
    const renderStatusText = document.getElementById("render-status-text");
    const renderPctText = document.getElementById("render-pct-text");

    const phonePlayer = document.getElementById("final-video-player");
    const playerPlaceholder = document.getElementById("player-placeholder");
    const exportCard = document.getElementById("export-card");
    const btnDownloadMp4 = document.getElementById("btn-download-mp4");
    const btnCopyCaption = document.getElementById("btn-copy-caption");
    const captionTextArea = document.getElementById("caption-text-area");
    const galleryGrid = document.getElementById("gallery-grid");

    // Initialize Presets
    async function loadPresets() {
        try {
            const res = await fetch("/api/presets");
            presets = await res.json();

            // Populate Voices
            voiceSelect.innerHTML = presets.voices.map(v => 
                `<option value="${v.id}" ${v.id === "auto" ? "selected" : ""}>${v.name}</option>`
            ).join("");

            // Populate Backgrounds
            bgSelect.innerHTML = presets.backgrounds.map(b => 
                `<option value="${b.id}" ${b.id === "auto" ? "selected" : ""}>${b.category ? `[${b.category}] ` : ""}${b.name}</option>`
            ).join("");

            loadGallery();
        } catch (e) {
            console.error("Failed to load presets:", e);
        }
    }

    // AI Story Analysis
    async function analyzeStory(story, title) {
        if (!story || story.trim().length < 20) {
            aiVibeBox.style.display = "none";
            return;
        }

        try {
            const res = await fetch("/api/ai/analyze-story", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ story, title })
            });
            const data = await res.json();
            if (data.status === "success") {
                latestAnalysis = data.analysis;
                vibeTitle.innerText = `AI Match: ${latestAnalysis.vibe}`;
                vibeRationale.innerText = latestAnalysis.rationale;
                vibeTagTone.innerText = `🎭 ${latestAnalysis.vibe}`;
                vibeTagVoice.innerText = `🎙️ Voice: ${latestAnalysis.voice_name}`;
                vibeTagBg.innerText = `🎬 B-Roll: ${latestAnalysis.bg_name}`;
                vibeTagSpeed.innerText = `⚡ Pacing: ${latestAnalysis.recommended_rate}`;
                aiVibeBox.style.display = "block";
            }
        } catch (e) {
            console.error("Analysis error:", e);
        }
    }

    btnApplyVibe.addEventListener("click", () => {
        if (!latestAnalysis) return;
        voiceSelect.value = latestAnalysis.recommended_voice;
        rateSelect.value = latestAnalysis.recommended_rate;
        bgSelect.value = latestAnalysis.recommended_bg;
        colorSelect.value = latestAnalysis.recommended_color;
        subStyleSelect.value = latestAnalysis.subtitle_style;

        btnApplyVibe.innerText = "✅ AI Settings Applied!";
        setTimeout(() => {
            btnApplyVibe.innerText = "✨ Apply AI Recommended Settings";
        }, 2000);
        updateWordCount();
    });

    // Word Counter & Live Analysis
    function handleStoryChange() {
        const text = storyTextInput.value.trim();
        const title = storyTitleInput.value.trim();
        const words = text ? text.split(/\s+/).length : 0;
        
        let speed = 1.1;
        if (rateSelect.value === "+25%") speed = 1.25;
        else if (rateSelect.value === "+18%") speed = 1.18;
        else if (rateSelect.value === "+15%") speed = 1.15;
        else if (rateSelect.value === "+8%") speed = 1.08;
        else if (rateSelect.value === "+0%") speed = 1.0;

        const estSeconds = Math.round((words / (150 * speed)) * 60);
        wordCounter.innerText = `${words} words (~${estSeconds}s)`;

        // Debounced AI analysis
        clearTimeout(analyzeTimeout);
        analyzeTimeout = setTimeout(() => {
            analyzeStory(text, title);
        }, 600);
    }

    storyTextInput.addEventListener("input", handleStoryChange);
    storyTitleInput.addEventListener("input", handleStoryChange);
    rateSelect.addEventListener("change", handleStoryChange);

    function setStory(title, text) {
        storyTitleInput.value = title || "";
        storyTextInput.value = text || "";
        handleStoryChange();
    }

    // Tab Switching
    document.querySelectorAll(".tab-btn").forEach(btn => {
        btn.addEventListener("click", () => {
            document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
            document.querySelectorAll(".tab-pane").forEach(p => p.classList.remove("active"));

            btn.classList.add("active");
            const tabId = `tab-${btn.dataset.tab}`;
            const targetPane = document.getElementById(tabId);
            if (targetPane) targetPane.classList.add("active");
        });
    });

    // 1. REDDIT ACTIONS
    const redditSelect = document.getElementById("reddit-subreddit-select");
    const btnFetchReddit = document.getElementById("btn-fetch-reddit");
    const redditCards = document.getElementById("reddit-cards");
    const redditUrlInput = document.getElementById("reddit-url-input");
    const btnScrapeRedditUrl = document.getElementById("btn-scrape-reddit-url");

    async function fetchRedditStories() {
        const sub = redditSelect.value;
        redditCards.innerHTML = `<div class="empty-text">Fetching viral stories from r/${sub}...</div>`;
        try {
            const res = await fetch(`/api/reddit/stories?subreddit=${encodeURIComponent(sub)}`);
            const data = await res.json();
            renderStoryCards(redditCards, data.stories);
        } catch (e) {
            redditCards.innerHTML = `<div class="empty-text">Failed to fetch stories: ${e}</div>`;
        }
    }

    btnFetchReddit.addEventListener("click", fetchRedditStories);

    btnScrapeRedditUrl.addEventListener("click", async () => {
        const url = redditUrlInput.value.trim();
        if (!url) return alert("Please enter a Reddit post URL");
        btnScrapeRedditUrl.innerText = "Scraping...";
        try {
            const res = await fetch("/api/reddit/url", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ url })
            });
            const data = await res.json();
            if (data.post) {
                setStory(data.post.title, data.post.story);
                alert("Reddit story loaded into editor!");
            }
        } catch (e) {
            alert("Could not scrape URL. Try another or paste text directly.");
        } finally {
            btnScrapeRedditUrl.innerText = "Scrape URL";
        }
    });

    // 2. QUORA ACTIONS
    const quoraSearchInput = document.getElementById("quora-search-input");
    const btnFetchQuora = document.getElementById("btn-fetch-quora");
    const quoraCards = document.getElementById("quora-cards");
    const quoraUrlInput = document.getElementById("quora-url-input");
    const btnScrapeQuoraUrl = document.getElementById("btn-scrape-quora-url");

    async function fetchQuoraStories() {
        const q = quoraSearchInput.value.trim() || "viral secrets";
        quoraCards.innerHTML = `<div class="empty-text">Searching Quora...</div>`;
        try {
            const res = await fetch(`/api/quora/stories?query=${encodeURIComponent(q)}`);
            const data = await res.json();
            renderStoryCards(quoraCards, data.stories, true);
        } catch (e) {
            quoraCards.innerHTML = `<div class="empty-text">Failed to fetch: ${e}</div>`;
        }
    }

    btnFetchQuora.addEventListener("click", fetchQuoraStories);

    btnScrapeQuoraUrl.addEventListener("click", async () => {
        const url = quoraUrlInput.value.trim();
        if (!url) return alert("Please enter a Quora question/answer URL");
        btnScrapeQuoraUrl.innerText = "Scraping...";
        try {
            const res = await fetch("/api/quora/url", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ url })
            });
            const data = await res.json();
            if (data.post) {
                setStory(data.post.question, data.post.story);
                alert("Quora story loaded into editor!");
            }
        } catch (e) {
            alert("Could not scrape Quora URL. Paste text directly.");
        } finally {
            btnScrapeQuoraUrl.innerText = "Scrape URL";
        }
    });

    // 3. YOUTUBE ACTIONS
    const ytUrlInput = document.getElementById("youtube-url-input");
    const btnFetchYoutube = document.getElementById("btn-fetch-youtube");
    const ytPreviewCard = document.getElementById("youtube-preview-card");
    const ytTitle = document.getElementById("yt-title");
    const ytChannel = document.getElementById("yt-channel");

    btnFetchYoutube.addEventListener("click", async () => {
        const url = ytUrlInput.value.trim();
        if (!url) return alert("Please enter a YouTube video URL");
        btnFetchYoutube.innerText = "Extracting...";
        try {
            const res = await fetch("/api/youtube/transcript", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ url })
            });
            const data = await res.json();
            if (data.video) {
                ytTitle.innerText = data.video.title;
                ytChannel.innerText = `Channel: ${data.video.channel} • Cleaned Transcript Ready`;
                ytPreviewCard.style.display = "block";
                setStory(data.video.title, data.video.story);
                alert("YouTube transcript extracted and formatted into viral script!");
            }
        } catch (e) {
            alert("Could not extract transcript. Ensure video has English captions available.");
        } finally {
            btnFetchYoutube.innerText = "Extract Transcript";
        }
    });

    // 4. AI STORY GENERATOR
    const aiCategorySelect = document.getElementById("ai-category-select");
    const aiDurationSelect = document.getElementById("ai-duration-select");
    const aiPromptInput = document.getElementById("ai-prompt-input");
    const geminiKeyInput = document.getElementById("gemini-key-input");
    const btnGenerateAi = document.getElementById("btn-generate-ai");

    btnGenerateAi.addEventListener("click", async () => {
        btnGenerateAi.innerText = "Generating Viral Script...";
        btnGenerateAi.disabled = true;

        try {
            const res = await fetch("/api/ai/generate", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    category: aiCategorySelect.value,
                    prompt: aiPromptInput.value.trim(),
                    duration: parseInt(aiDurationSelect.value),
                    api_key: geminiKeyInput.value.trim() || null
                })
            });
            const data = await res.json();
            if (data.result) {
                setStory(data.result.title, data.result.story);
            }
        } catch (e) {
            alert("Error generating story: " + e);
        } finally {
            btnGenerateAi.innerText = "✨ Generate Viral Script with AI";
            btnGenerateAi.disabled = false;
        }
    });

    // Helper: Render Story Cards
    function renderStoryCards(container, list, isQuora = false) {
        if (!list || list.length === 0) {
            container.innerHTML = `<div class="empty-text">No stories found. Try a different topic or paste link.</div>`;
            return;
        }
        container.innerHTML = list.map((item, idx) => {
            const title = isQuora ? item.question : item.title;
            const meta = isQuora 
                ? `Topic: ${item.topic} • Author: ${item.author} • 👍 ${item.upvotes.toLocaleString()}`
                : `r/${item.subreddit} • u/${item.author} • 🔺 ${item.upvotes.toLocaleString()}`;
            return `
                <div class="story-card" data-idx="${idx}">
                    <div class="card-title">${title}</div>
                    <div class="card-snippet">${item.story}</div>
                    <div class="card-meta">${meta}</div>
                </div>
            `;
        }).join("");

        container.querySelectorAll(".story-card").forEach((card, idx) => {
            card.addEventListener("click", () => {
                container.querySelectorAll(".story-card").forEach(c => c.classList.remove("selected"));
                card.classList.add("selected");
                const item = list[idx];
                setStory(isQuora ? item.question : item.title, item.story);
            });
        });
    }

    // Voice Preview
    const btnPreviewAudio = document.getElementById("btn-preview-audio");
    const audioPreviewPlayer = document.getElementById("audio-preview-player");
    const previewIndicator = document.getElementById("preview-voice-indicator");

    btnPreviewAudio.addEventListener("click", async () => {
        const text = storyTextInput.value.trim() || storyTitleInput.value.trim() || "Welcome to viral TikTok stories.";
        btnPreviewAudio.innerText = "Generating sample...";
        try {
            const res = await fetch("/api/tts/preview", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    text: text,
                    voice: voiceSelect.value,
                    rate: rateSelect.value
                })
            });
            const data = await res.json();
            if (data.status === "success") {
                audioPreviewPlayer.src = `${data.audio_url}?t=${Date.now()}`;
                audioPreviewPlayer.style.display = "block";
                audioPreviewPlayer.play();
                if (previewIndicator) {
                    previewIndicator.innerText = `Used: ${data.voice_used} (${data.rate_used})`;
                }
            }
        } catch (e) {
            alert("Voice preview failed: " + e);
        } finally {
            btnPreviewAudio.innerText = "🔊 Test Voice Sample";
        }
    });

    // Custom Background Upload
    const uploadBgInput = document.getElementById("upload-bg-input");
    uploadBgInput.addEventListener("change", async (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const formData = new FormData();
        formData.append("file", file);

        try {
            const res = await fetch("/api/backgrounds/upload", {
                method: "POST",
                body: formData
            });
            const data = await res.json();
            if (data.status === "success") {
                alert(`Uploaded ${data.filename}! Reloading backgrounds...`);
                loadPresets();
            }
        } catch (err) {
            alert("Upload failed: " + err);
        }
    });

    // 5. GENERATE VIDEO
    btnGenerateVideo.addEventListener("click", async () => {
        const title = storyTitleInput.value.trim();
        const story = storyTextInput.value.trim();

        if (!story) {
            return alert("Please select or write a story first!");
        }

        btnGenerateVideo.disabled = true;
        btnGenerateVideo.innerText = "⏳ AI GENERATING VIDEO...";
        renderProgressBox.style.display = "block";
        renderProgressFill.style.width = "10%";
        renderStatusText.innerText = "AI analyzing story & matching optimal voice...";
        renderPctText.innerText = "10%";

        try {
            let fakePct = 15;
            const progressInterval = setInterval(() => {
                if (fakePct < 85) {
                    fakePct += Math.floor(Math.random() * 7) + 3;
                    if (fakePct > 85) fakePct = 85;
                    renderProgressFill.style.width = `${fakePct}%`;
                    renderPctText.innerText = `${fakePct}%`;
                    if (fakePct > 65) renderStatusText.innerText = "Burning karaoke captions with FFmpeg...";
                    else if (fakePct > 40) renderStatusText.innerText = "Scrubbing/Composing 9:16 vertical b-roll footage...";
                    else if (fakePct > 20) renderStatusText.innerText = "Synthesizing voiceover with Edge-TTS...";
                }
            }, 1200);

            const res = await fetch("/api/video/generate", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    title: title || "Viral TikTok Story",
                    story: story,
                    voice: voiceSelect.value,
                    rate: rateSelect.value,
                    subtitle_style: subStyleSelect.value,
                    highlight_color: colorSelect.value,
                    background_id: bgSelect.value || "auto"
                })
            });

            clearInterval(progressInterval);
            const data = await res.json();

            if (data.status === "success") {
                renderProgressFill.style.width = "100%";
                renderPctText.innerText = "100%";
                const aiInfo = data.data.ai_match;
                renderStatusText.innerText = `Complete! AI matched Voice: ${aiInfo.voice_name} with ${aiInfo.bg_name}`;

                // Display video in player
                const videoUrl = `/outputs/${data.data.video_filename}?t=${Date.now()}`;
                phonePlayer.src = videoUrl;
                phonePlayer.style.display = "block";
                playerPlaceholder.style.display = "none";
                phonePlayer.play();

                // Export actions
                exportCard.style.display = "block";
                btnDownloadMp4.href = videoUrl;
                btnDownloadMp4.setAttribute("download", data.data.video_filename);
                captionTextArea.value = data.data.caption;

                loadGallery();
            } else {
                alert("Generation error: " + (data.detail || "Unknown error"));
            }
        } catch (e) {
            alert("Generation failed: " + e);
        } finally {
            btnGenerateVideo.disabled = false;
            btnGenerateVideo.innerText = "⚡ GENERATE VIRAL TIKTOK VIDEO";
        }
    });

    // Copy Caption
    btnCopyCaption.addEventListener("click", () => {
        captionTextArea.select();
        navigator.clipboard.writeText(captionTextArea.value);
        btnCopyCaption.innerText = "✅ Copied to Clipboard!";
        setTimeout(() => {
            btnCopyCaption.innerText = "📋 Copy TikTok Caption & Hashtags";
        }, 2000);
    });

    // Gallery
    async function loadGallery() {
        try {
            const res = await fetch("/api/gallery");
            const data = await res.json();
            if (data.videos && data.videos.length > 0) {
                galleryGrid.innerHTML = data.videos.map(v => `
                    <div class="gallery-item" data-url="${v.url}">
                        <span>▶️</span>
                        <span class="gallery-item-name">${v.filename}</span>
                        <span class="gallery-item-size">${v.size_mb} MB</span>
                    </div>
                `).join("");

                galleryGrid.querySelectorAll(".gallery-item").forEach(item => {
                    item.addEventListener("click", () => {
                        const url = item.dataset.url;
                        phonePlayer.src = `${url}?t=${Date.now()}`;
                        phonePlayer.style.display = "block";
                        playerPlaceholder.style.display = "none";
                        phonePlayer.play();

                        exportCard.style.display = "block";
                        btnDownloadMp4.href = url;
                    });
                });
            } else {
                galleryGrid.innerHTML = `<p class="empty-text">No videos rendered yet.</p>`;
            }
        } catch (e) {
            console.error("Gallery load error:", e);
        }
    }

    document.getElementById("btn-refresh-gallery").addEventListener("click", loadGallery);

    // Initial triggers
    loadPresets();
    fetchRedditStories();
});
