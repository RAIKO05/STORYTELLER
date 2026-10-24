document.addEventListener("DOMContentLoaded", () => {
    // State
    let presets = null;
    let latestAnalysis = null;
    let analyzeTimeout = null;
    let customBgmFilename = null;

    // Elements
    const wordCounter = document.getElementById("word-counter");
    const storyTitleInput = document.getElementById("story-title");
    const storyTextInput = document.getElementById("story-text");

    const voiceSelect = document.getElementById("voice-select");
    const rateSelect = document.getElementById("rate-select");
    const voiceVolSlider = document.getElementById("voice-vol-slider");
    const voiceVolVal = document.getElementById("voice-vol-val");

    const bgMusicSelect = document.getElementById("bg-music-select");
    const bgmVolSlider = document.getElementById("bgm-vol-slider");
    const bgmVolVal = document.getElementById("bgm-vol-val");
    const uploadBgmInput = document.getElementById("upload-bgm-input");

    const bgSelect = document.getElementById("background-select");
    const uploadBgInput = document.getElementById("upload-bg-input");

    const subStyleSelect = document.getElementById("subtitle-style-select");
    const colorSelect = document.getElementById("color-select");
    const fontSelect = document.getElementById("font-select");
    const fontSizeSelect = document.getElementById("font-size-select");
    const marginVSelect = document.getElementById("margin-v-select");
    const caseSelect = document.getElementById("case-select");

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

    // Slider Listeners
    voiceVolSlider.addEventListener("input", () => {
        voiceVolVal.innerText = `${voiceVolSlider.value}%`;
    });

    bgmVolSlider.addEventListener("input", () => {
        bgmVolVal.innerText = `${bgmVolSlider.value}%`;
    });

    // Custom BGM Upload
    uploadBgmInput.addEventListener("change", async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const formData = new FormData();
        formData.append("file", file);
        try {
            const res = await fetch("/api/audio/upload", { method: "POST", body: formData });
            const data = await res.json();
            if (data.status === "success") {
                customBgmFilename = data.filename;
                const opt = document.createElement("option");
                opt.value = "custom";
                opt.text = `🎵 Custom: ${data.filename}`;
                bgMusicSelect.appendChild(opt);
                bgMusicSelect.value = "custom";
                alert(`Uploaded background music: ${data.filename}`);
            }
        } catch (err) {
            alert("Music upload failed: " + err);
        }
    });

    // Custom B-Roll Upload
    uploadBgInput.addEventListener("change", async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const formData = new FormData();
        formData.append("file", file);
        try {
            const res = await fetch("/api/backgrounds/upload", { method: "POST", body: formData });
            const data = await res.json();
            if (data.status === "success") {
                alert(`Uploaded ${data.filename}! Reloading backgrounds...`);
                loadPresets();
            }
        } catch (err) {
            alert("Upload failed: " + err);
        }
    });

    // Initialize Presets
    async function loadPresets() {
        try {
            const res = await fetch("/api/presets");
            presets = await res.json();

            // Populate Voices
            if (presets.voices) {
                voiceSelect.innerHTML = presets.voices.map(v => 
                    `<option value="${v.id}" ${v.id === "auto" ? "selected" : ""}>${v.name}</option>`
                ).join("");
            }

            // Populate Backgrounds
            if (presets.backgrounds) {
                bgSelect.innerHTML = presets.backgrounds.map(b => 
                    `<option value="${b.id}" ${b.id === "auto" ? "selected" : ""}>${b.category ? `[${b.category}] ` : ""}${b.name}</option>`
                ).join("");
            }

            // Populate Background Music if available
            if (presets.bg_music) {
                bgMusicSelect.innerHTML = presets.bg_music.map(m => 
                    `<option value="${m.id}" ${m.id === "none" ? "selected" : ""}>${m.name}</option>`
                ).join("");
            }

            // Populate Fonts if available
            if (presets.fonts) {
                fontSelect.innerHTML = presets.fonts.map(f => 
                    `<option value="${f.id}" ${f.id === "Arial Black" ? "selected" : ""}>${f.name}</option>`
                ).join("");
            }

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
        }, 2200);
    });

    // Word Counter
    function updateWordCount() {
        const text = storyTextInput.value.trim();
        const words = text ? text.split(/\s+/).filter(w => w.length > 0).length : 0;
        const seconds = Math.round((words / 150) * 60);
        wordCounter.innerText = `${words} words • ~${seconds}s video`;

        clearTimeout(analyzeTimeout);
        analyzeTimeout = setTimeout(() => {
            analyzeStory(text, storyTitleInput.value.trim());
        }, 400);
    }

    storyTextInput.addEventListener("input", updateWordCount);
    storyTitleInput.addEventListener("input", () => {
        clearTimeout(analyzeTimeout);
        analyzeTimeout = setTimeout(() => {
            analyzeStory(storyTextInput.value.trim(), storyTitleInput.value.trim());
        }, 400);
    });

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

    // 0. CURATED VIRAL SCRIPTS (1-Tap Fast Loading - Matching iPhone Default)
    const curatedStories = {
        garlic: {
            title: "AITA for revealing my sister's fake allergy at her own wedding dinner?",
            story: "My sister claimed to be severely allergic to garlic for three years until I caught her eating garlic bread at an Italian restaurant. Yesterday at her wedding reception, she started screaming at the coordinator over garlic potatoes. I took the microphone, congratulated the bride, and played the video of her eating garlic bread. Half the family walked out. Am I the jerk?"
        },
        monitor: {
            title: "I bought a vintage baby monitor, but it's picking up a room that doesn't exist.",
            story: "Three weeks ago I set up a vintage audio baby monitor in my daughter's nursery. At 3:14 AM on Thursday, the speaker clicked on with static, followed by a rocking chair slowly creaking on wooden floorboards. My daughter's room has carpet. When I ran in, she was asleep, but the receiver whispered: 'Hush now, he's looking through the door.' The monitor had no batteries inside."
        },
        script: {
            title: "My boss stole my bonus, so I accidentally automated his entire job in Python.",
            story: "My corporate manager took our entire departmental bonus pool and assigned it to himself under 'executive optimization.' I didn't get mad. I opened Python. Over three weeks, I built five scripts that handled every single task he was responsible for: invoice approval, vendor reordering, and weekly charts. During the executive board meeting, the VP asked why the company was paying him two hundred thousand a year when a ten-line script did his job in eight seconds. He was fired before lunch."
        },
        parking: {
            title: "My neighbor kept parking his truck across three spaces, so I called the city.",
            story: "An entitled guy parked his lifted pickup truck diagonally across three assigned spaces for six months. When polite notes were left, he wrote back: 'Call a tow truck if you're broke.' I found a city fire-code ordinance that bans modified bumpers from blocking sprinkler access points in subterranean garages. I submitted timestamped photos. Two days later, three city code officers seized his truck and issued twelve thousand dollars in retroactive penalties. He now rides a lime scooter."
        },
        heist: {
            title: "The genius heist of the Antwerp Diamond Center where fifty million was stolen without an alarm.",
            story: "In February 2003, Italian masterminds pulled off the most impossible heist in modern history. The Antwerp Diamond Vault was protected by Doppler radar, seismic sensors, an infrared heat curtain, and magnetic triggers. On the night of the heist, the team bypassed the infrared sensors using ordinary women's hairspray to coat the thermal mirrors. They walked out with fifty million dollars in uncut diamonds and not a single diamond has ever been found."
        }
    };

    function selectCuratedStory(key) {
        const item = curatedStories[key];
        if (!item) return;
        storyTitleInput.value = item.title;
        storyTextInput.value = item.story;
        updateWordCount();

        document.querySelectorAll(".curated-card").forEach(c => {
            if (c.dataset.key === key) {
                c.classList.add("active");
                c.style.borderColor = "var(--accent)";
            } else {
                c.classList.remove("active");
                c.style.borderColor = "var(--border)";
            }
        });
    }

    document.querySelectorAll(".curated-card").forEach(card => {
        card.addEventListener("click", () => {
            selectCuratedStory(card.dataset.key);
        });
    });

    // LUXURY THEME ENGINE (Matches iOS AppTheme.swift: obsidian, emerald, midnight, oled, sand)
    const themeNames = {
        obsidian: "Bayan Obsidian",
        emerald: "Moroccan Emerald",
        midnight: "Sapphire Midnight",
        oled: "Pure OLED Black",
        sand: "Imperial Sand"
    };

    const currentThemeLabel = document.getElementById("current-theme-label");
    const themeModal = document.getElementById("theme-modal");
    const btnOpenThemeModal = document.getElementById("btn-open-theme-modal");
    const btnCloseThemeModal = document.getElementById("btn-close-theme-modal");

    function applyTheme(themeKey) {
        if (!themeNames[themeKey]) themeKey = "obsidian";
        document.body.className = `theme-${themeKey}`;
        if (currentThemeLabel) {
            currentThemeLabel.innerText = themeNames[themeKey];
        }
        localStorage.setItem("storyteller_theme", themeKey);

        document.querySelectorAll(".theme-tile").forEach(t => {
            if (t.dataset.theme === themeKey) {
                t.classList.add("active");
            } else {
                t.classList.remove("active");
            }
        });
    }

    if (btnOpenThemeModal && themeModal) {
        btnOpenThemeModal.addEventListener("click", () => {
            themeModal.classList.add("open");
        });
    }

    if (btnCloseThemeModal && themeModal) {
        btnCloseThemeModal.addEventListener("click", () => {
            themeModal.classList.remove("open");
        });
    }

    document.querySelectorAll(".theme-tile").forEach(tile => {
        tile.addEventListener("click", () => {
            const chosen = tile.dataset.theme;
            applyTheme(chosen);
            themeModal.classList.remove("open");
        });
    });

    // IPHONE CONNECT MODAL
    const connectModal = document.getElementById("connect-modal");
    const btnOpenConnectModal = document.getElementById("btn-open-connect-modal");
    const btnCloseConnectModal = document.getElementById("btn-close-connect-modal");
    const connectIpDisplay = document.getElementById("connect-ip-display");

    async function updateNetworkInfo() {
        try {
            const res = await fetch("/api/network-info");
            const data = await res.json();
            if (data.iphone_url && connectIpDisplay) {
                connectIpDisplay.innerText = data.iphone_url;
            }
        } catch (e) {
            console.error("Network info error:", e);
        }
    }

    if (btnOpenConnectModal && connectModal) {
        btnOpenConnectModal.addEventListener("click", () => {
            updateNetworkInfo();
            connectModal.classList.add("open");
        });
    }

    const modeBtnIos = document.getElementById("mode-btn-ios");
    if (modeBtnIos && connectModal) {
        modeBtnIos.addEventListener("click", () => {
            updateNetworkInfo();
            connectModal.classList.add("open");
        });
    }

    if (btnCloseConnectModal && connectModal) {
        btnCloseConnectModal.addEventListener("click", () => {
            connectModal.classList.remove("open");
        });
    }

    if (connectIpDisplay) {
        connectIpDisplay.style.cursor = "pointer";
        connectIpDisplay.title = "Click to copy URL";
        connectIpDisplay.addEventListener("click", () => {
            const text = connectIpDisplay.innerText.trim();
            navigator.clipboard.writeText(text);
            const original = connectIpDisplay.innerText;
            connectIpDisplay.innerText = "✅ Copied to Clipboard!";
            setTimeout(() => {
                connectIpDisplay.innerText = original;
            }, 1800);
        });
    }

    // Global modal close on backdrop click or ESC
    window.addEventListener("click", (e) => {
        if (e.target === themeModal) themeModal.classList.remove("open");
        if (e.target === connectModal) connectModal.classList.remove("open");
        if (typeof hookModal !== "undefined" && e.target === hookModal) hookModal.classList.remove("open");
    });

    window.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
            if (themeModal) themeModal.classList.remove("open");
            if (connectModal) connectModal.classList.remove("open");
            if (typeof hookModal !== "undefined" && hookModal) hookModal.classList.remove("open");
        }
    });

    // VIRAL HOOK DOCTOR
    const hookModal = document.getElementById("hook-doctor-modal");
    const btnOpenHookDoctor = document.getElementById("btn-open-hook-doctor");
    const btnCloseHookDoctor = document.getElementById("btn-close-hook-doctor");
    const hookCardsList = document.getElementById("hook-cards-list");

    if (btnOpenHookDoctor && hookModal) {
        btnOpenHookDoctor.addEventListener("click", async () => {
            const title = storyTitleInput.value.trim();
            const story = storyTextInput.value.trim();
            if (!story) return alert("Please select or enter a story first!");

            hookCardsList.innerHTML = "<p class='empty-text'>Analyzing story & generating viral hooks...</p>";
            hookModal.classList.add("open");

            try {
                const res = await fetch("/api/ai/hook-doctor", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ title, story })
                });
                const data = await res.json();
                if (data.status === "success" && data.hooks) {
                    hookCardsList.innerHTML = data.hooks.map(h => `
                        <div class="hook-card">
                            <div class="hook-card-header">
                                <span class="hook-card-style">${h.style}</span>
                                <span class="hook-badge">${h.badge}</span>
                            </div>
                            <div class="hook-card-title">"${h.hook_title}"</div>
                            <div class="hook-card-body">${h.hook_opening}</div>
                            <div class="hook-card-footer">
                                <span class="hook-card-strategy">💡 ${h.viral_strategy}</span>
                                <button class="btn-apply-hook" data-title="${encodeURIComponent(h.hook_title)}" data-opening="${encodeURIComponent(h.hook_opening)}">
                                    Apply Hook
                                </button>
                            </div>
                        </div>
                    `).join("");

                    hookCardsList.querySelectorAll(".btn-apply-hook").forEach(btn => {
                        btn.addEventListener("click", () => {
                            const newTitle = decodeURIComponent(btn.dataset.title);
                            const newOpening = decodeURIComponent(btn.dataset.opening);
                            storyTitleInput.value = newTitle;
                            if (!storyTextInput.value.toLowerCase().includes(newOpening.toLowerCase().substring(0, 25))) {
                                storyTextInput.value = `${newOpening}\n\n${storyTextInput.value}`;
                            }
                            updateWordCount();
                            hookModal.classList.remove("open");
                        });
                    });
                }
            } catch (err) {
                hookCardsList.innerHTML = `<p class='empty-text'>Error generating hooks: ${err}</p>`;
            }
        });
    }

    if (btnCloseHookDoctor && hookModal) {
        btnCloseHookDoctor.addEventListener("click", () => {
            hookModal.classList.remove("open");
        });
    }

    // MULTI-PART STORY SPLITTER
    let activeStoryParts = null;
    const btnSplitStory = document.getElementById("btn-split-story");
    const storyPartsBar = document.getElementById("story-parts-bar");
    const btnPart1 = document.getElementById("btn-part-1");
    const btnPart2 = document.getElementById("btn-part-2");

    if (btnSplitStory) {
        btnSplitStory.addEventListener("click", async () => {
            if (activeStoryParts) {
                activeStoryParts = null;
                storyPartsBar.style.display = "none";
                btnSplitStory.innerText = "✂️ Split Parts";
                return;
            }
            const title = storyTitleInput.value.trim();
            const story = storyTextInput.value.trim();
            if (!story) return alert("Please select or enter a story first!");

            try {
                const res = await fetch("/api/ai/split-story", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ title, story })
                });
                const data = await res.json();
                if (data.status === "success" && data.parts && data.parts.is_splittable) {
                    activeStoryParts = data.parts;
                    storyPartsBar.style.display = "flex";
                    btnSplitStory.innerText = "✕ Merge Parts";

                    // Default to Part 1
                    storyTitleInput.value = activeStoryParts.part1_title;
                    storyTextInput.value = activeStoryParts.part1_story;
                    btnPart1.classList.add("active");
                    btnPart2.classList.remove("active");
                    updateWordCount();
                } else {
                    alert("Story is too short to split into two parts (< 70 words).");
                }
            } catch (e) {
                alert("Split error: " + e);
            }
        });
    }

    if (btnPart1 && btnPart2) {
        btnPart1.addEventListener("click", () => {
            if (!activeStoryParts) return;
            btnPart1.classList.add("active");
            btnPart2.classList.remove("active");
            storyTitleInput.value = activeStoryParts.part1_title;
            storyTextInput.value = activeStoryParts.part1_story;
            updateWordCount();
        });

        btnPart2.addEventListener("click", () => {
            if (!activeStoryParts) return;
            btnPart2.classList.add("active");
            btnPart1.classList.remove("active");
            storyTitleInput.value = activeStoryParts.part2_title;
            storyTextInput.value = activeStoryParts.part2_story;
            updateWordCount();
        });
    }

    // 1. REDDIT SCRAPER
    async function fetchRedditStories() {
        const sub = document.getElementById("reddit-subreddit-select").value;
        const container = document.getElementById("reddit-cards");
        container.innerHTML = "<p class='empty-text'>Fetching trending Reddit posts...</p>";

        try {
            const res = await fetch(`/api/reddit/stories?subreddit=${encodeURIComponent(sub)}`);
            const data = await res.json();
            if (data.status === "success" && data.stories.length > 0) {
                container.innerHTML = data.stories.slice(0, 5).map(s => `
                    <div class="story-card" data-title="${encodeURIComponent(s.title)}" data-story="${encodeURIComponent(s.story)}">
                        <div class="story-card-title">${s.title}</div>
                        <div class="story-card-snippet">${s.story.substring(0, 140)}...</div>
                        <div class="meta-tag">🔺 ${s.upvotes.toLocaleString()} upvotes • u/${s.author}</div>
                    </div>
                `).join("");

                container.querySelectorAll(".story-card").forEach(card => {
                    card.addEventListener("click", () => {
                        storyTitleInput.value = decodeURIComponent(card.dataset.title);
                        storyTextInput.value = decodeURIComponent(card.dataset.story);
                        updateWordCount();
                    });
                });
            } else {
                container.innerHTML = "<p class='empty-text'>No stories found in subreddit.</p>";
            }
        } catch (e) {
            container.innerHTML = `<p class='empty-text'>Error fetching Reddit: ${e}</p>`;
        }
    }

    document.getElementById("btn-fetch-reddit").addEventListener("click", fetchRedditStories);

    document.getElementById("btn-scrape-reddit-url").addEventListener("click", async () => {
        const url = document.getElementById("reddit-url-input").value.trim();
        if (!url) return alert("Please enter a Reddit post URL");
        try {
            const res = await fetch("/api/reddit/scrape-url", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ url })
            });
            const data = await res.json();
            if (data.status === "success") {
                storyTitleInput.value = data.story.title;
                storyTextInput.value = data.story.story;
                updateWordCount();
            } else {
                alert("Failed to scrape post: " + data.detail);
            }
        } catch (e) {
            alert("Scrape error: " + e);
        }
    });

    // 2. QUORA SCRAPER
    document.getElementById("btn-fetch-quora").addEventListener("click", async () => {
        const query = document.getElementById("quora-search-input").value.trim() || "viral secrets";
        const container = document.getElementById("quora-cards");
        container.innerHTML = "<p class='empty-text'>Searching Quora answers...</p>";

        try {
            const res = await fetch(`/api/quora/stories?query=${encodeURIComponent(query)}`);
            const data = await res.json();
            if (data.status === "success" && data.stories.length > 0) {
                container.innerHTML = data.stories.slice(0, 4).map(s => `
                    <div class="story-card" data-title="${encodeURIComponent(s.question)}" data-story="${encodeURIComponent(s.story)}">
                        <div class="story-card-title">${s.question}</div>
                        <div class="story-card-snippet">${s.story.substring(0, 140)}...</div>
                        <div class="meta-tag">💡 Topic: ${s.topic || 'Insight'}</div>
                    </div>
                `).join("");

                container.querySelectorAll(".story-card").forEach(card => {
                    card.addEventListener("click", () => {
                        storyTitleInput.value = decodeURIComponent(card.dataset.title);
                        storyTextInput.value = decodeURIComponent(card.dataset.story);
                        updateWordCount();
                    });
                });
            } else {
                container.innerHTML = "<p class='empty-text'>No Quora answers found.</p>";
            }
        } catch (e) {
            container.innerHTML = `<p class='empty-text'>Error searching Quora: ${e}</p>`;
        }
    });

    document.getElementById("btn-scrape-quora-url").addEventListener("click", async () => {
        const url = document.getElementById("quora-url-input").value.trim();
        if (!url) return alert("Please enter a Quora question/answer URL");
        try {
            const res = await fetch("/api/quora/scrape-url", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ url })
            });
            const data = await res.json();
            if (data.status === "success") {
                storyTitleInput.value = data.story.question;
                storyTextInput.value = data.story.story;
                updateWordCount();
            } else {
                alert("Failed to scrape Quora: " + data.detail);
            }
        } catch (e) {
            alert("Scrape error: " + e);
        }
    });

    // 3. YOUTUBE TRANSCRIPT
    document.getElementById("btn-fetch-youtube").addEventListener("click", async () => {
        const url = document.getElementById("youtube-url-input").value.trim();
        if (!url) return alert("Please enter a YouTube video URL");

        const btn = document.getElementById("btn-fetch-youtube");
        btn.innerText = "⏳ Extracting...";
        btn.disabled = true;

        try {
            const res = await fetch("/api/youtube/scrape", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ url })
            });
            const data = await res.json();
            if (data.status === "success") {
                const yt = data.data;
                document.getElementById("yt-title").innerText = yt.title;
                document.getElementById("yt-channel").innerText = `Channel: ${yt.channel}`;
                document.getElementById("youtube-preview-card").style.display = "block";

                storyTitleInput.value = yt.title;
                storyTextInput.value = yt.story;
                updateWordCount();
            } else {
                alert("Failed to extract YouTube transcript: " + data.detail);
            }
        } catch (e) {
            alert("YouTube extraction error: " + e);
        } finally {
            btn.innerText = "Extract Transcript";
            btn.disabled = false;
        }
    });

    // 4. AI STORY WRITER
    document.getElementById("btn-generate-ai").addEventListener("click", async () => {
        const category = document.getElementById("ai-category-select").value;
        const duration = parseInt(document.getElementById("ai-duration-select").value, 10);
        const prompt = document.getElementById("ai-prompt-input").value.trim();
        const apiKey = document.getElementById("gemini-key-input").value.trim();

        const btn = document.getElementById("btn-generate-ai");
        btn.innerText = "✨ Generating Viral Script...";
        btn.disabled = true;

        try {
            const res = await fetch("/api/ai/generate-story", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    category,
                    prompt,
                    duration,
                    api_key: apiKey || null
                })
            });
            const data = await res.json();
            if (data.status === "success") {
                storyTitleInput.value = data.result.title;
                storyTextInput.value = data.result.story;
                updateWordCount();
            } else {
                alert("AI Generation error: " + data.detail);
            }
        } catch (e) {
            alert("AI Writer error: " + e);
        } finally {
            btn.innerText = "✨ Generate Full Viral Script with AI";
            btn.disabled = false;
        }
    });

    // TTS AUDIO PREVIEW
    const btnPreviewAudio = document.getElementById("btn-preview-audio");
    const audioPreviewPlayer = document.getElementById("audio-preview-player");
    const previewVoiceIndicator = document.getElementById("preview-voice-indicator");

    btnPreviewAudio.addEventListener("click", async () => {
        const text = storyTextInput.value.trim() || storyTitleInput.value.trim() || "Welcome to StoryTeller Pro. Creating viral videos in seconds.";
        btnPreviewAudio.disabled = true;
        btnPreviewAudio.innerText = "⏳ Generating...";

        try {
            const res = await fetch("/api/tts/preview", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    text,
                    voice: voiceSelect.value,
                    rate: rateSelect.value,
                    pitch: "+0Hz"
                })
            });
            const data = await res.json();
            if (data.status === "success") {
                audioPreviewPlayer.src = `${data.audio_url}?t=${Date.now()}`;
                audioPreviewPlayer.style.display = "block";
                audioPreviewPlayer.play();
                previewVoiceIndicator.innerText = `Sample: ${data.voice_used} (${data.rate_used})`;
            } else {
                alert("Preview error: " + data.detail);
            }
        } catch (e) {
            alert("Audio test error: " + e);
        } finally {
            btnPreviewAudio.disabled = false;
            btnPreviewAudio.innerText = "🔊 Test Voice Sample";
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
        renderStatusText.innerText = "Analyzing story & synthesizing full voiceover...";
        renderPctText.innerText = "10%";

        try {
            let fakePct = 15;
            const progressInterval = setInterval(() => {
                if (fakePct < 85) {
                    fakePct += Math.floor(Math.random() * 6) + 3;
                    if (fakePct > 85) fakePct = 85;
                    renderProgressFill.style.width = `${fakePct}%`;
                    renderPctText.innerText = `${fakePct}%`;
                    if (fakePct > 65) renderStatusText.innerText = "Burning karaoke captions & audio mixing with FFmpeg...";
                    else if (fakePct > 40) renderStatusText.innerText = "Composing 9:16 vertical background footage...";
                    else if (fakePct > 20) renderStatusText.innerText = "Synthesizing voiceover with Edge-TTS...";
                }
            }, 1200);

            const payload = {
                title: title || "Viral TikTok Story",
                story: story,
                voice: voiceSelect.value,
                rate: rateSelect.value,
                subtitle_style: subStyleSelect.value,
                highlight_color: colorSelect.value,
                font_name: fontSelect.value,
                font_size: parseInt(fontSizeSelect.value, 10),
                margin_v: parseInt(marginVSelect.value, 10),
                text_case: caseSelect.value,
                background_id: bgSelect.value || "auto",
                bg_music_id: bgMusicSelect.value === "custom" ? null : bgMusicSelect.value,
                bg_music_volume: parseFloat(bgmVolSlider.value) / 100.0,
                voice_volume: parseFloat(voiceVolSlider.value) / 100.0,
                custom_bg_music_filename: customBgmFilename
            };

            const res = await fetch("/api/video/generate", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(payload)
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

    // Video Gallery Library
    async function loadGallery() {
        try {
            const res = await fetch("/api/gallery");
            const data = await res.json();
            if (data.videos && data.videos.length > 0) {
                galleryGrid.innerHTML = data.videos.map(v => {
                    const thumb = v.thumbnail_url 
                        ? `<img src="${v.thumbnail_url}" alt="thumb">` 
                        : `<span style="font-size: 16px;">▶️</span>`;
                    const d = new Date(v.created_at * 1000);
                    const dateStr = d.toLocaleDateString() + " " + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                    
                    return `
                        <div class="gallery-card" data-url="${v.url}" data-filename="${v.filename}">
                            <div class="gallery-info">
                                <div class="gallery-thumb-box">${thumb}</div>
                                <div class="gallery-meta">
                                    <div class="gallery-name" title="${v.filename}">${v.filename}</div>
                                    <div class="gallery-sub">${v.size_mb} MB • ${dateStr}</div>
                                </div>
                            </div>
                            <div class="gallery-actions">
                                <a href="${v.url}" download="${v.filename}" class="btn-icon" title="Download MP4" onclick="event.stopPropagation();">⬇️</a>
                                <button class="btn-del" title="Delete Video" data-del="${v.filename}" onclick="event.stopPropagation();">🗑️</button>
                            </div>
                        </div>
                    `;
                }).join("");

                // Click to play
                galleryGrid.querySelectorAll(".gallery-card").forEach(card => {
                    card.addEventListener("click", () => {
                        const url = card.dataset.url;
                        phonePlayer.src = `${url}?t=${Date.now()}`;
                        phonePlayer.style.display = "block";
                        playerPlaceholder.style.display = "none";
                        phonePlayer.play();

                        exportCard.style.display = "block";
                        btnDownloadMp4.href = url;
                        btnDownloadMp4.setAttribute("download", card.dataset.filename);
                    });
                });

                // Delete handlers
                galleryGrid.querySelectorAll(".btn-del").forEach(btn => {
                    btn.addEventListener("click", async () => {
                        const fn = btn.dataset.del;
                        if (!confirm(`Delete ${fn} permanently from PC?`)) return;
                        try {
                            const delRes = await fetch(`/api/gallery/${fn}`, { method: "DELETE" });
                            const delData = await delRes.json();
                            if (delData.status === "success") {
                                loadGallery();
                            }
                        } catch (e) {
                            alert("Failed to delete video: " + e);
                        }
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
    const savedTheme = localStorage.getItem("storyteller_theme") || "obsidian";
    applyTheme(savedTheme);
    selectCuratedStory("garlic");

    loadPresets();
    fetchRedditStories();

    // ========================================================
    // CORE DOMAIN 2: THE "LIQUID GLASS" FUTURE UI KIT (PC WEB)
    // ========================================================
    function initFluidGlassView() {
        const canvas = document.getElementById("fluid-ripple-canvas");
        if (!canvas) return;
        const ctx = canvas.getContext("2d");
        let width = canvas.width = window.innerWidth;
        let height = canvas.height = window.innerHeight;

        window.addEventListener("resize", () => {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
        });

        const ripples = [];

        function addRipple(x, y) {
            if (ripples.length < 12) {
                ripples.push({
                    x, y,
                    radius: 0,
                    maxRadius: Math.min(width, height) * 0.28,
                    speed: 3.2,
                    opacity: 1.0
                });
            }
        }

        window.addEventListener("pointerdown", (e) => addRipple(e.clientX, e.clientY));
        window.addEventListener("pointermove", (e) => {
            if (Math.random() < 0.12) addRipple(e.clientX, e.clientY);
        });

        function renderRipples() {
            ctx.clearRect(0, 0, width, height);

            for (let i = ripples.length - 1; i >= 0; i--) {
                const r = ripples[i];
                r.radius += r.speed;
                r.opacity = Math.max(0, 1.0 - (r.radius / r.maxRadius));

                if (r.opacity <= 0.01) {
                    ripples.splice(i, 1);
                    continue;
                }

                // Refraction Caustic Ring
                ctx.beginPath();
                ctx.arc(r.x, r.y, r.radius, 0, Math.PI * 2);
                ctx.strokeStyle = `rgba(255, 255, 255, ${r.opacity * 0.28})`;
                ctx.lineWidth = Math.max(1, 4 * r.opacity);
                ctx.stroke();

                // Specular Sheen Rim
                ctx.beginPath();
                ctx.arc(r.x, r.y, Math.max(0, r.radius - 3), 0, Math.PI * 2);
                ctx.strokeStyle = `rgba(223, 177, 91, ${r.opacity * 0.22})`;
                ctx.lineWidth = Math.max(0.5, 2 * r.opacity);
                ctx.stroke();
            }

            requestAnimationFrame(renderRipples);
        }

        renderRipples();
    }

    function initLiquidButton() {
        const btn = document.getElementById("btn-generate-video");
        if (!btn) return;

        btn.addEventListener("pointermove", (e) => {
            const rect = btn.getBoundingClientRect();
            const relX = (e.clientX - rect.left) / rect.width - 0.5;
            const relY = (e.clientY - rect.top) / rect.height - 0.5;
            const stretchX = relX * 14;
            const stretchY = relY * 9;
            btn.style.transform = `translate(${stretchX}px, ${stretchY}px) scale(1.02)`;
        });

        btn.addEventListener("pointerleave", () => {
            btn.style.transform = "translate(0px, 0px) scale(1)";
        });
    }

    initFluidGlassView();
    initLiquidButton();
});
