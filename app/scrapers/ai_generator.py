import os
import re
import random
from typing import Dict, Optional
from app.utils.helpers import clean_text_for_tts

VIRAL_PROMPT_TEMPLATES = {
    "aita": {
        "title": "AITA for canceling my husband's 30th birthday trip after finding secret tickets?",
        "hooks": [
            "Am I the bad guy for walking out of my own anniversary dinner?",
            "Am I the bad guy for refusing to let my mother-in-law hold our newborn baby?",
            "Am I the bad guy for secretly taking a DNA test on my daughter?",
            "Am I the bad guy for selling the family car after my brother crashed it twice?"
        ],
        "stories": [
            (
                "My husband and I have been married for four years. For his thirtieth birthday, I spent six months saving up to book "
                "a dream vacation to Switzerland. Yesterday, while borrowing his laptop to print our hotel confirmations, I noticed his "
                "browser history had a receipt from an airline for two first-class tickets to Hawaii on the exact same weekend. "
                "When I clicked the booking, the second passenger wasn't me—it was his 'female best friend' from college who he swore was like a sister to him. "
                "I didn't yell. I didn't scream. I quietly called the airline, canceled my Switzerland bookings, drained my personal savings account, "
                "and packed his suitcases out onto the driveway with the printed Hawaii itinerary taped to his front door. "
                "Now his mother is blowing up my phone screaming that I overreacted and destroyed his milestone birthday. Was I wrong?"
            ),
            (
                "Two weeks ago, my sister-in-law announced she was getting married in Tuscany and made it a strictly child-free wedding. "
                "I have a six-month-old breastfeeding infant, so I politely declined the invitation and sent a generous four-hundred-dollar espresso machine as a gift. "
                "Last night, she called me sobbing and furious, accusing me of sabotaging her special day because she wanted my husband to be the best man "
                "and demanded that I leave my baby with a stranger babysitter in a foreign country for four days. "
                "When my husband backed me up and said he wouldn't go without his family, she told the entire extended family that I am a controlling monster. "
                "Now my in-laws are threatening to cut us off. Tell me, am I the jerk here?"
            )
        ]
    },
    "revenge": {
        "title": "My toxic boss fired me on a Friday. By Monday, his biggest client followed me.",
        "hooks": [
            "My boss took credit for my million-dollar project, so I gave him all the credit when it collapsed.",
            "My neighbor built a fence three feet onto my property, so I hired a land surveyor.",
            "A coworker tried to frame me for company theft, but forgot about the security cameras."
        ],
        "stories": [
            (
                "For three years, I worked sixty-hour weeks at a boutique architectural firm. My managing partner constantly belittled my designs, "
                "stole credit during client pitches, and refused to give me the promotion he promised in writing. "
                "Last month, our biggest tech client requested a complete redesign of their twelve-story headquarters. "
                "My boss told the client that I was incompetent and that only he could handle the project, then secretly dumped the entire eighty-hour blueprint workload on my desk. "
                "I finished the drawings, encrypted the files with a personal private key, and resigned that very afternoon. "
                "On Monday morning, the client asked my boss to present the final blueprints. My boss couldn't open the files, couldn't explain the engineering math, "
                "and panicked live on Zoom. The client called me directly, fired the agency, and hired me as an independent consultant at triple my previous salary."
            )
        ]
    },
    "confession": {
        "title": "I've been swapping my coworker's regular coffee for decaf for three months.",
        "hooks": [
            "I found out my fiancée has a secret second family in another state.",
            "I accidentally discovered my boss's embezzlement spreadsheet while looking for an invoice.",
            "I have been living rent-free in my university's abandoned basement for two semesters."
        ],
        "stories": [
            (
                "I work in a high-stress trading office where one senior partner makes it his life's mission to scream at junior analysts before 9 AM. "
                "He always bragged that his ruthless aggression came from drinking six shots of Cuban espresso every single morning, and he demanded that "
                "the office assistants brew his private French press. Three months ago, after he brought an intern to tears over a paperclip, "
                "I swapped his high-caffeine roast with Swiss-water organic decaf. For ninety days, he has been sipping decaf coffee. "
                "The office has never been quieter, his blood pressure has normalized, and yesterday he actually brought in homemade blueberry muffins and thanked everyone. "
                "He thinks his new mindfulness meditation app cured his anger issues. I will take this secret to my grave."
            )
        ]
    },
    "mystery": {
        "title": "The strange reason why every cruise ship has an empty cabin on Deck 3.",
        "hooks": [
            "If you ever hear code 'Bravo' on a luxury cruise ship, do not look out your window.",
            "Three rules you must follow if you ever find an abandoned stairwell in the national forest.",
            "The terrifying true story of the lighthouse keeper who vanished mid-storm."
        ],
        "stories": [
            (
                "Most people think a modern cruise ship is just a floating hotel with water slides and all-you-can-eat buffets. "
                "But after working four contracts as an electrical engineer on mega-liners across the Atlantic, there is one rule the bridge crew never breaks: "
                "Cabin three-zero-four on the lower crew deck is permanently welded shut. In nineteen ninety-eight, during a transatlantic repositioning crossing, "
                "the motion sensors in that room triggered forty-seven times in the middle of a hurricane while the ship was completely empty of passengers. "
                "When the chief security officer pried the door open with a crowbar, the room was bone-dry, but the carpet was covered in fresh, wet footprints "
                "leading from the closed closet directly into the wall. To this day, whenever the ship enters open ocean waters, the ship's internal telephone system "
                "still receives three rings from cabin three-zero-four at exactly three-fifteen in the morning."
            )
        ]
    }
}

class AIViralStoryGenerator:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY")

    def analyze_story_vibe(self, story_text: str, title: str = "") -> Dict:
        """
        Intelligently analyzes story sentiment, subject, and pacing
        to recommend the optimal voice actor, speech speed, subtitle color,
        and storytelling background theme.
        """
        full_text = f"{title} {story_text}".lower()

        # Keywords scoring
        mystery_keywords = ["creepy", "haunted", "ship", "ocean", "disappeared", "abandoned", "night", "dark", "secret", "rules", "never", "police", "warning", "dead", "footprints", "forest", "vanished", "space", "stars", "alien"]
        drama_keywords = ["husband", "wife", "wedding", "bride", "sister", "mother-in-law", "mil", "in-laws", "family", "cheating", "baby", "toxic", "relationship", "dilemma", "pregnant", "divorce", "jerk", "asshole", "bad guy"]
        revenge_keywords = ["boss", "fired", "coworker", "job", "salary", "client", "office", "company", "promoted", "quit", "compliance", "landlord", "landlady", "paycheck", "hr", "corporate", "lawyer", "million", "destroy", "wreck", "car", "crash"]
        confession_keywords = ["secret", "confession", "nobody knows", "guilt", "lied", "lottery", "cash", "money", "ashamed", "years ago", "truth", "discovered", "stole", "hidden", "night drive", "wealth", "quiet"]
        humor_keywords = ["tifu", "accidentally", "funny", "screwed up", "zoom", "embarrassing", "stupid", "hilarious", "laugh", "haircut", "roblox", "game", "chaos", "chase"]

        def score(keywords):
            return sum(1 for kw in keywords if re.search(rf"\b{kw}\b", full_text))

        m_score = score(mystery_keywords)
        d_score = score(drama_keywords)
        r_score = score(revenge_keywords)
        c_score = score(confession_keywords)
        h_score = score(humor_keywords)

        scores = [
            ("mystery", m_score),
            ("drama", d_score),
            ("revenge", r_score),
            ("confession", c_score),
            ("humor", h_score)
        ]
        scores.sort(key=lambda x: x[1], reverse=True)
        top_vibe = scores[0][0] if scores[0][1] > 0 else "drama"

        if top_vibe == "mystery":
            bg_choice = "aurora_galaxy" if any(w in full_text for w in ["space", "sky", "alien", "stars"]) else "dark_cinematic"
            bg_name = "Deep Space Galaxy & Aurora" if bg_choice == "aurora_galaxy" else "Dark Atmospheric Mystery"
            return {
                "vibe": "Spooky / Mystery / Unsolved",
                "vibe_key": "mystery",
                "recommended_voice": "en-US-EricNeural",
                "voice_name": "Eric (Serious / True Crime Mystery)",
                "recommended_rate": "+5%",
                "recommended_color": "&HFFFF00&", # Electric Cyan
                "color_name": "Electric Cyan",
                "recommended_bg": bg_choice,
                "bg_name": bg_name,
                "subtitle_style": "single",
                "rationale": "High suspense and tension detected. Eric's deep, steady delivery paired with deliberate +5% pacing and Electric Cyan text maximizes dramatic retention."
            }
        elif top_vibe == "revenge":
            # Check if car crash or hydraulic destruction
            bg_choice = "beamng_crashes" if any(w in full_text for w in ["car", "crash", "smash", "destroy"]) else "gta_stunts"
            bg_name = "BeamNG.drive Car Crashes & Stunts" if bg_choice == "beamng_crashes" else "GTA V Mega Ramp Stunts"
            return {
                "vibe": "Epic Revenge / Workplace Drama",
                "vibe_key": "revenge",
                "recommended_voice": "en-US-GuyNeural",
                "voice_name": "Guy (Energetic Viral Narrator)",
                "recommended_rate": "+15%",
                "recommended_color": "&H00FF00&", # Neon Lime Green
                "color_name": "Neon Lime Green",
                "recommended_bg": bg_choice,
                "bg_name": bg_name,
                "subtitle_style": "karaoke",
                "rationale": "High-energy revenge narrative detected. Guy's confident voice at +15% speed with high-contrast Neon Lime highlights keeps viewers hooked through the climax."
            }
        elif top_vibe == "confession":
            # Synthwave drive for late night or ASMR for intimate secrets
            bg_choice = "synthwave_drive" if any(w in full_text for w in ["drive", "lottery", "cash", "million", "night", "city"]) else "satisfying_asmr"
            bg_name = "Cyberpunk Synthwave Sunset Night Drive" if bg_choice == "synthwave_drive" else "Satisfying Kinetic Sand & Soap Cutting"
            return {
                "vibe": "Deep Secret / Personal Confession",
                "vibe_key": "confession",
                "recommended_voice": "en-US-ChristopherNeural",
                "voice_name": "Christopher (Storyteller Male - Deep & Cinematic)",
                "recommended_rate": "+10%",
                "recommended_color": "&H00FFFF&", # TikTok Yellow
                "color_name": "TikTok Neon Yellow",
                "recommended_bg": bg_choice,
                "bg_name": bg_name,
                "subtitle_style": "karaoke",
                "rationale": "Intimate storytelling tone detected. Christopher's rich voice creates strong emotional trust, paired with mesmerizing visuals for maximum watch-time."
            }
        elif top_vibe == "humor":
            bg_choice = "temple_run" if "chase" in full_text else "subway_surfers"
            bg_name = "Temple Run 2 Classic Run" if bg_choice == "temple_run" else "Subway Surfers Fast Run"
            return {
                "vibe": "Comedy / Chaos / TIFU",
                "vibe_key": "humor",
                "recommended_voice": "en-US-GuyNeural",
                "voice_name": "Guy (Energetic Viral Narrator)",
                "recommended_rate": "+18%",
                "recommended_color": "&H00FFFF&",
                "color_name": "TikTok Neon Yellow",
                "recommended_bg": bg_choice,
                "bg_name": bg_name,
                "subtitle_style": "single",
                "rationale": "Fast-paced comedic storytelling detected. Snappy +18% speed with high-velocity single word pops mirrors viral TikTok comedy formats."
            }
        else:
            female_words = ["my husband", "he wanted", "my boyfriend", "bride", "mother", "sister"]
            is_female = any(w in full_text for w in female_words)
            chosen_voice = "en-US-JennyNeural" if is_female else "en-US-ChristopherNeural"
            voice_name = "Jenny (Natural Conversational Female)" if is_female else "Christopher (Storyteller Male)"

            bg_choice = "roblox_obby" if "teen" in full_text else "minecraft_parkour"
            bg_name = "Roblox Tower Obby Parkour" if bg_choice == "roblox_obby" else "Minecraft Parkour (Vertical 9:16)"

            return {
                "vibe": "Moral Dilemma / Relationship Drama",
                "vibe_key": "drama",
                "recommended_voice": chosen_voice,
                "voice_name": voice_name,
                "recommended_rate": "+12%",
                "recommended_color": "&H00FFFF&",
                "color_name": "TikTok Neon Yellow",
                "recommended_bg": bg_choice,
                "bg_name": bg_name,
                "subtitle_style": "karaoke",
                "rationale": f"Relatable interpersonal drama detected. Matched with {voice_name} at +12% pacing over {bg_name} to drive intense comment debates."
            }

    def generate_story(self, category: str = "aita", prompt_hint: str = "", target_duration: int = 60) -> Dict:
        """
        Generates a high-retention viral story script.
        """
        if self.api_key:
            try:
                from google import genai
                client = genai.Client(api_key=self.api_key)
                
                system_instruction = (
                    "You are a master viral TikTok & YouTube Shorts storytelling scriptwriter. "
                    "Write an addictive, high-retention viral story in the first-person perspective ('I'). "
                    "Rules for maximum retention: "
                    "1. The FIRST sentence must be an irresistible 3-second hook that creates immediate curiosity or moral outrage. "
                    "2. Build fast-paced narrative tension without fluff or unnecessary details. "
                    "3. Include a dramatic turning point or plot twist. "
                    "4. End with an open-ended provocative question to drive thousands of comments. "
                    "5. Keep the total length around 150-220 words (around 60-75 seconds of natural speech). "
                    "6. Return ONLY the story text, without stage directions or brackets."
                )
                
                user_msg = f"Write a viral {category.upper()} story. "
                if prompt_hint:
                    user_msg += f"Premise or inspiration: {prompt_hint}. "
                user_msg += f"Target duration: {target_duration} seconds."

                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=user_msg,
                    config={"system_instruction": system_instruction, "temperature": 0.85}
                )
                
                story_text = response.text.strip()
                cleaned = clean_text_for_tts(story_text)
                sentences = cleaned.split(". ")
                title = sentences[0] if sentences else f"Viral {category.upper()} Story"
                
                vibe_analysis = self.analyze_story_vibe(cleaned, title)

                return {
                    "source": "Gemini AI (2.5 Flash)",
                    "category": category,
                    "title": title[:90],
                    "story": cleaned,
                    "vibe_analysis": vibe_analysis
                }
            except Exception as e:
                print(f"[AIGenerator] Gemini API error, falling back to template engine: {e}")

        cat_key = category.lower() if category.lower() in VIRAL_PROMPT_TEMPLATES else "aita"
        template_group = VIRAL_PROMPT_TEMPLATES[cat_key]
        
        chosen_hook = random.choice(template_group["hooks"])
        chosen_story = random.choice(template_group["stories"])
        
        final_story = chosen_story
        if prompt_hint:
            final_story = chosen_story.replace(" Swiss", " European")
            
        cleaned = clean_text_for_tts(final_story)
        vibe_analysis = self.analyze_story_vibe(cleaned, chosen_hook)

        return {
            "source": "Algorithmic Viral Engine",
            "category": category,
            "title": chosen_hook,
            "story": cleaned,
            "vibe_analysis": vibe_analysis
        }

    def generate_viral_hooks(self, title: str, story: str) -> list:
        """AI Hook Doctor: Generates 3 viral hook variations (Shock, POV, Moral Dilemma)."""
        combined = f"{title} {story}".lower()
        has_family = any(w in combined for w in ["sister", "brother", "mom", "dad", "family", "wedding", "husband", "wife"])
        has_work = any(w in combined for w in ["boss", "manager", "job", "fired", "bonus", "company", "corporate"])
        has_mystery = any(w in combined for w in ["monitor", "ghost", "creepy", "door", "night", "whisper", "house"])
        has_crime = any(w in combined for w in ["heist", "diamond", "stolen", "police", "robbery", "vault"])

        # 1. Shock & Curiosity
        if has_family:
            shock_title = "The 10-second video that completely destroyed my sister's wedding."
            shock_opening = "I never thought three years of keeping my mouth shut would end like this, but when she called the coordinator a murderer in front of two hundred guests, I lost all patience."
        elif has_work:
            shock_title = "How I got my CEO to fire my boss in under 8 seconds."
            shock_opening = "If my manager hadn't stolen our entire departmental bonus pool, he would still have his two hundred thousand dollar a year job today."
        elif has_mystery:
            shock_title = "Whatever you do, never buy a vintage baby monitor at a garage sale."
            shock_opening = "At 3:14 AM on Thursday, the static crackled to life in my daughter's room, but the sound coming out of the receiver was impossible."
        elif has_crime:
            shock_title = "The $50 million diamond vault heist that used an ordinary can of hairspray."
            shock_opening = "They bypassed seismic sensors, Doppler radar, and infrared heat curtains, and the police still have no idea where the diamonds went."
        else:
            shock_title = "Wait until the very end, because nobody saw this twist coming."
            shock_opening = "I used to think people were exaggerating when they told me stories like this, until the exact same thing happened to me yesterday."

        # 2. POV Immersion
        if has_family:
            pov_title = "POV: You find out your sister's 3-year allergy was a lie."
            pov_opening = "POV: You walk into a random Italian trattoria on your lunch break and catch the one person who forced the entire family to eat bland food inhaling garlic bread."
        elif has_work:
            pov_title = "POV: Your manager steals your bonus so you automate his career away."
            pov_opening = "POV: You open Python after hours, write five automation scripts, and wait for the executive board meeting to casually show the VP your screen."
        elif has_mystery:
            pov_title = "POV: The baby monitor turns on, but there are no batteries inside."
            pov_opening = "POV: You hear a rocking chair creaking on wooden floorboards in your daughter's carpeted bedroom at three in the morning."
        else:
            pov_title = "POV: You finally expose the one person who thought they were untouchable."
            pov_opening = "POV: You have the exact timestamped evidence, and the moment has finally arrived to lay it all out on the table."

        # 3. Moral Dilemma
        if has_family:
            dilemma_title = "Am I the jerk for playing this video at my sister's wedding?"
            dilemma_opening = "Half the guests walked out, my mother hasn't spoken to me in 48 hours, but I need you to hear the full story before you judge me."
        elif has_work:
            dilemma_title = "Was I wrong for destroying my boss's career over a bonus?"
            dilemma_opening = "HR called my actions ruthless, but he took fifteen thousand dollars straight out of our pockets. Tell me in the comments if I crossed the line."
        else:
            dilemma_title = "Listen to the full story before you decide if I was wrong."
            dilemma_opening = "Everyone in my circle is divided right down the middle on this, and I genuinely need an unbiased third party to tell me the truth."

        return [
            {
                "style": "Curiosity & Shock",
                "badge": "🔥 89% RETENTION",
                "hook_title": shock_title,
                "hook_opening": shock_opening,
                "viral_strategy": "Creates an instant high-stakes curiosity gap that stops viewers from scrolling in the first 2 seconds."
            },
            {
                "style": "POV Immersion",
                "badge": "👁️ TIKTOK VIRAL",
                "hook_title": pov_title,
                "hook_opening": pov_opening,
                "viral_strategy": "Puts the viewer directly in the protagonist's shoes, triggering mirror neurons and higher shares."
            },
            {
                "style": "Moral Dilemma",
                "badge": "💬 5X COMMENTS",
                "hook_title": dilemma_title,
                "hook_opening": dilemma_opening,
                "viral_strategy": "Triggers strong debate in the comments section, signaling the algorithm to push to the FYP."
            }
        ]

    def split_story_into_parts(self, title: str, story: str) -> dict:
        """Splits long stories (> 80 words) into high-retention Part 1 (Cliffhanger) & Part 2."""
        words = story.split()
        if len(words) < 70:
            return {
                "is_splittable": False,
                "part1_title": title,
                "part1_story": story,
                "part2_title": "",
                "part2_story": ""
            }

        sentences = re.split(r'(?<=[.!?])\s+', story.strip())
        target_words = int(len(words) * 0.55)
        cumulative = 0
        split_idx = max(1, len(sentences) // 2)

        for i, s in enumerate(sentences):
            cumulative += len(s.split())
            if cumulative >= target_words:
                split_idx = i
                break

        p1_text = " ".join(sentences[:split_idx+1])
        p2_text = " ".join(sentences[split_idx+1:])

        cliffhanger = " What happened next left everyone completely speechless... Follow and check my profile for Part 2! ➡️"
        part1_final = p1_text + cliffhanger
        part2_final = "Welcome back to Part 2! Here is what happened next: " + p2_text

        clean_title = re.sub(r'\(Part\s*\d+\)', '', title).strip()

        return {
            "is_splittable": True,
            "part1_title": f"{clean_title} (Part 1) 🔥",
            "part1_story": part1_final,
            "part2_title": f"{clean_title} (Part 2 - The Conclusion) 💥",
            "part2_story": part2_final
        }

    def generate_viral_hashtags(self, title: str, story: str) -> list:
        """Generates dynamic category-specific viral hashtags."""
        combined = f"{title} {story}".lower()
        tags = ["#StoryTime", "#TikTokStories", "#ViralTikTok", "#Shorts"]

        if any(w in combined for w in ["sister", "wedding", "aita", "family"]):
            tags.extend(["#AITA", "#RedditStories", "#FamilyDrama", "#WeddingDrama", "#Exposed"])
        elif any(w in combined for w in ["boss", "job", "bonus", "work"]):
            tags.extend(["#PettyRevenge", "#MaliciousCompliance", "#WorkTok", "#CorporateLife", "#InstantKarma"])
        elif any(w in combined for w in ["monitor", "creepy", "mystery"]):
            tags.extend(["#CreepyStories", "#TrueHorror", "#Unexplained", "#Mystery", "#PlotTwist"])
        elif any(w in combined for w in ["heist", "diamond", "crime"]):
            tags.extend(["#TrueCrime", "#HeistStory", "#Mastermind", "#Unsolved", "#CrimeTok"])
        else:
            tags.extend(["#RedditReadings", "#CrazyStory", "#DidThisHappen", "#PlotTwist"])

        return tags[:8]
