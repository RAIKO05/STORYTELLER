import Foundation

public class NativeScraperService {
    public static let shared = NativeScraperService()

    private init() {}

    // MARK: - Direct Reddit Scraping via Public JSON API
    public func fetchRedditStories(subreddit: String = "AmItheAsshole") async throws -> [Story] {
        let cleanSub = subreddit.replacingOccurrences(of: "r/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = "https://www.reddit.com/r/\(cleanSub)/hot.json?limit=25"

        guard let url = URL(string: endpoint) else {
            return getFallbackStories(for: cleanSub)
        }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 StoryTeller/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 6

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return getFallbackStories(for: cleanSub)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataObj = json?["data"] as? [String: Any],
                  let children = dataObj["children"] as? [[String: Any]] else {
                return getFallbackStories(for: cleanSub)
            }

            var results: [Story] = []
            for child in children {
                guard let postData = child["data"] as? [String: Any] else { continue }
                let isStickied = postData["stickied"] as? Bool ?? false
                if isStickied { continue }

                let title = (postData["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                var selftext = (postData["selftext"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let author = postData["author"] as? String ?? "anonymous"
                let ups = postData["ups"] as? Int ?? 100
                let id = postData["id"] as? String ?? UUID().uuidString

                // Filter out empty selftext or too short
                if selftext.count < 120 { continue }

                // Clean up reddit markdown artifacts
                selftext = cleanRedditText(selftext)

                results.append(Story(
                    id: id,
                    title: title,
                    story: selftext,
                    author: "u/\(author)",
                    upvotes: ups,
                    subreddit: "r/\(cleanSub)",
                    topic: cleanSub
                ))
            }

            return results.isEmpty ? getFallbackStories(for: cleanSub) : results
        } catch {
            return getFallbackStories(for: cleanSub)
        }
    }

    public func fetchRedditURL(_ urlString: String) async throws -> Story {
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.contains("?") {
            cleanURL = String(cleanURL.split(separator: "?")[0])
        }
        if cleanURL.hasSuffix("/") {
            cleanURL.removeLast()
        }
        cleanURL += ".json"

        guard let url = URL(string: cleanURL) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 StoryTeller/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard let firstListing = json?.first,
              let dataObj = firstListing["data"] as? [String: Any],
              let children = dataObj["children"] as? [[String: Any]],
              let postData = children.first?["data"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let title = (postData["title"] as? String ?? "Viral Reddit Story").trimmingCharacters(in: .whitespacesAndNewlines)
        var selftext = (postData["selftext"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let author = postData["author"] as? String ?? "anonymous"
        let ups = postData["ups"] as? Int ?? 1500
        let sub = postData["subreddit"] as? String ?? "Reddit"

        selftext = cleanRedditText(selftext)

        return Story(
            id: UUID().uuidString,
            title: title,
            story: selftext,
            author: "u/\(author)",
            upvotes: ups,
            subreddit: "r/\(sub)",
            topic: sub
        )
    }

    private func cleanRedditText(_ text: String) -> String {
        var clean = text
        // Remove markdown links [text](url) -> text
        let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\([^\\)]+\\)", options: [])
        if let regex = regex {
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "$1")
        }
        // Remove EDIT: sections if at the end
        if let editIndex = clean.range(of: "\nEDIT:", options: .caseInsensitive) {
            clean = String(clean[..<editIndex.lowerBound])
        }
        if let updateIndex = clean.range(of: "\nUpdate:", options: .caseInsensitive) {
            clean = String(clean[..<updateIndex.lowerBound])
        }
        // Normalize multiple linebreaks
        clean = clean.replacingOccurrences(of: "\n\n+", with: " ", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\n", with: " ")
        clean = clean.replacingOccurrences(of: "TL;DR.*", with: "", options: [.regularExpression, .caseInsensitive])
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - On-Device Algorithmic AI Viral Story Generator
    public func generateOfflineAIStory(category: String, prompt: String = "", duration: Int = 60) -> Story {
        let cat = category.lowercased()

        if cat.contains("aita") || cat.contains("drama") {
            return generateAITAStory(prompt: prompt)
        } else if cat.contains("revenge") {
            return generateRevengeStory(prompt: prompt)
        } else if cat.contains("scary") || cat.contains("horror") {
            return generateScaryStory(prompt: prompt)
        } else if cat.contains("confess") || cat.contains("secret") {
            return generateConfessionStory(prompt: prompt)
        } else if cat.contains("lifehack") || cat.contains("psych") {
            return generatePsychologyHackStory(prompt: prompt)
        } else if cat.contains("shower") || cat.contains("thought") {
            return generateShowerThoughtsStory(prompt: prompt)
        } else if cat.contains("crime") || cat.contains("mystery") {
            return generateTrueCrimeStory(prompt: prompt)
        } else {
            return generateAITAStory(prompt: prompt)
        }
    }

    private func generateAITAStory(prompt: String) -> Story {
        let stories = [
            (
                "AITA for locking my sister-in-law out of my house after she invited 15 strangers for Thanksgiving?",
                "Am I the jerk for locking my sister-in-law out in the freezing rain? Last week, my husband and I agreed to host Thanksgiving dinner for immediate family only, which was seven people. Two days before, his sister casually mentioned she had invited a few friends from her hiking club. I told her firmly that our dining table only seats eight and we couldn't accommodate anyone else. She laughed it off and texted 'don't worry, they eat fast.' Fast forward to Thanksgiving afternoon. The doorbell rings and there are sixteen people standing on our front porch with empty Tupperware containers. She hadn't even brought food, she literally invited half a college sports team to get free gourmet turkey. I stepped outside, looked her dead in the eyes, locked the deadbolt, and told them the nearest restaurant was four miles down the road. My husband's phone hasn't stopped blowing up with angry texts calling me evil. But was I really in the wrong?"
            ),
            (
                "AITA for revealing my sister's fake allergy at her own wedding dinner?",
                "My sister has claimed to be severely allergic to garlic and onions for three years. Every single family meal, birthday party, and holiday has been ruined because our entire extended family has to eat bland, boiled food just for her. But two weeks ago, I walked into an Italian trattoria across town on my lunch break. Who was sitting in the corner booth inhaling a plate of four-cheese garlic bread and onion soup? My sister. She turned ghost white and begged me not to say anything. Yesterday was her wedding reception. The caterer accidentally brought out the original garlic-roasted potatoes instead of her special plate. She started screaming at the wedding coordinator, calling her a murderer in front of two hundred guests. I couldn't take it anymore. I took the microphone, congratulated the bride, and played the ten-second video of her inhaling garlic bread two weeks earlier. The entire room went dead silent. Half the family left. Am I the jerk?"
            ),
            (
                "AITA for uninviting my best friend from my vacation after finding my clothes on her Vinted?",
                "I let my best friend stay at my apartment for two weeks while I was traveling for work. When I returned, three of my favorite designer jackets and four vintage dresses were mysteriously missing. She swore she had no idea where they were and suggested my landlord had maintenance people over. Three days later, my coworker showed me a viral listing on a secondhand fashion app. It was my best friend wearing my vintage Burberry trench coat in my own apartment mirror, selling it for two hundred dollars. She had listed eleven of my items. We were supposed to fly to Hawaii together this Friday on flights I paid for with my airline miles. I cancelled her ticket without telling her and booked a first-class upgrade for myself instead. Now her mom is calling me selfish because she took time off work. Was I wrong?"
            )
        ]
        let picked = stories.randomElement()!
        return Story(
            title: picked.0,
            story: picked.1,
            author: "u/Throwaway_MoralDilemma",
            upvotes: Int.random(in: 4500...18500),
            subreddit: "r/AmItheAsshole",
            topic: "AITA"
        )
    }

    private func generateRevengeStory(prompt: String) -> Story {
        let stories = [
            (
                "My boss tried to steal my bonus, so I accidentally automated his entire department out of a job.",
                "My corporate manager told me during my performance review that our division didn't have the budget to pay my promised fifteen thousand dollar bonus. Five minutes later, I saw him walking out to the parking garage showing off his brand-new company-leased Porsche. He had taken the entire departmental bonus pool and assigned it to himself under 'executive optimization.' I didn't get mad. I just opened Python. Over the next three weeks, I built five automated scripts that handled every single task he was responsible for: invoice approval, vendor reordering, and weekly progress charts. I scheduled the scripts to run silently under the VP of Operations' internal dashboard with full attribution to my employee ID. During the quarterly executive board meeting, the Vice President pulled up the report and asked why the company was paying my manager two hundred thousand dollars a year when a ten-line script was doing his exact job in eight seconds. He was fired before lunch."
            ),
            (
                "My neighbor kept parking his truck across three of our assigned spaces, so I called the city.",
                "My apartment building has assigned underground parking. For six months straight, an entitled guy on the top floor parked his lifted pickup truck diagonally across spaces fourteen, fifteen, and sixteen. Two of those spaces belonged to a sweet retired couple with mobility issues. Every polite note left on his windshield was crumpled and thrown on the ground. One day he even wrote back: 'Call a tow truck if you're broke.' So I did some research. It turns out our city has a strict fire-code ordinance that bans commercial-grade modified bumpers from blocking sprinkler access points in subterranean garages, carrying a daily eight-hundred-dollar municipal fine. I took thirty timestamped photos and submitted them through the official city portal. Two days later, three city code enforcement officers showed up with two heavy-duty impound trucks. His truck was seized and he received twelve thousand dollars in retroactive municipal penalties. He now rides a lime scooter to work."
            )
        ]
        let picked = stories.randomElement()!
        return Story(
            title: picked.0,
            story: picked.1,
            author: "u/KarmaDeliveredCold",
            upvotes: Int.random(in: 8900...24000),
            subreddit: "r/MaliciousCompliance",
            topic: "Revenge"
        )
    }

    private func generateScaryStory(prompt: String) -> Story {
        let stories = [
            (
                "I bought a vintage baby monitor at a garage sale, but it's picking up a room that doesn't exist.",
                "Three weeks ago, I set up a vintage audio baby monitor in my daughter's nursery on the second floor. The first few nights were peaceful. But on Thursday at 3:14 in the morning, the speaker clicked on with a quiet, raspy static. At first, I thought it was radio interference from a nearby trucker. Then I heard a rocking chair slowly creaking on wooden floorboards. Back and forth. Back and forth. My heart dropped, because my daughter's room has wall-to-wall carpet. I ran into her room. She was fast asleep, the nursery was dead silent, but the receiver in my hand was still transmitting the rocking chair. Then a soft woman's voice whispered through the speaker: 'Hush now, he's looking through the door.' I looked down at the model sticker on the back of the monitor. It was an unpowered dummy display unit. It didn't even have batteries inside."
            ),
            (
                "My smart doorbell detected someone standing outside my front door at 2 AM, but the street was completely empty.",
                "My smart security camera buzzed my phone at two o'clock in the morning with a notification: 'Person detected at front entrance.' I opened the live feed expecting to see a delivery driver or a stray cat. The porch light was on, illuminate the empty concrete steps. Nothing was there. But the camera's bounding box was locked onto the center of the screen, tracking a tall humanoid figure as it slowly walked closer to the camera lens. The sensor kept saying: 'Distance: five feet... three feet... one foot.' Then the camera microphone picked up the unmistakable sound of fingernails gently tapping on the glass. I live on the fourteenth floor of a high-rise with no balcony."
            )
        ]
        let picked = stories.randomElement()!
        return Story(
            title: picked.0,
            story: picked.1,
            author: "u/ParanormalLogs",
            upvotes: Int.random(in: 6700...19000),
            subreddit: "r/nosleep",
            topic: "Scary Stories"
        )
    }

    private func generateConfessionStory(prompt: String) -> Story {
        let stories = [
            (
                "I accidentally became a millionaire because of a database glitch and I haven't told a soul in seven years.",
                "Seven years ago, I was a broke college student working late night at a regional credit union. While testing an internal debit transaction settlement protocol, the test server had a timeout error and somehow credited four hundred and twenty thousand dollars into an inactive checking account that belonged to a holding company I had opened for a business class. I panicked and spent three weeks expecting the FBI to kick down my door. But the quarterly audit passed, the ledger balanced itself with an obscure corporate reserve, and nobody ever noticed. I never spent a penny on flashy cars or luxury clothes. I invested every single dollar into index funds and real estate. Today that portfolio is worth over three point four million dollars. My family thinks I make seventy thousand dollars a year as an IT analyst, and I plan to take this secret to my grave."
            ),
            (
                "I secretly swapped my company's expensive decaf espresso beans with regular beans and our productivity skyrocketed.",
                "I am the office manager at a prominent hedge fund. Three years ago, the CEO instituted a mandatory wellness policy that banned all caffeinated coffee from the executive kitchen, claiming caffeine creates erratic decision-making. Within three weeks, the entire floor was lethargic, irritable, and missing critical market openings. So on a Sunday night, I bought industrial bags of dark-roast high-octane Ethiopian espresso and poured them into the labeled 'Organic Swiss Decaf' canisters. Over the next six months, the firm had its most profitable trading quarter in company history. The CEO even gave a keynote speech at a leadership conference crediting the decaf transition for the team's laser focus. I've been quietly swapping the beans every two weeks for four years. If I get caught, half of Wall Street will collapse."
            )
        ]
        let picked = stories.randomElement()!
        return Story(
            title: picked.0,
            story: picked.1,
            author: "u/SilentObserver99",
            upvotes: Int.random(in: 12000...35000),
            subreddit: "r/confession",
            topic: "Confessions"
        )
    }

    private func generatePsychologyHackStory(prompt: String) -> Story {
        let stories = [
            (
                "Three dark psychology tricks that will make anyone respect you instantly in any room.",
                "Here are three psychological hacks that feel almost illegal to know. First: The Silence Power Play. When someone insults you or tries to undermine you in a meeting, look them directly in their left eye and stay completely silent for four seconds before saying: 'Are you okay?' This triggers instant subconscious embarrassment and forces them to explain themselves. Second: The Benjamin Franklin Effect. If you want someone who dislikes you to warm up to you, ask them for a tiny, effortless favor, like holding your coffee for ten seconds or borrowing a pen. Their brain will subconsciously rationalize: 'I only help people I like, so I must like this person.' Third: The Door-in-the-Face Technique. When negotiating, always ask for something absurdly massive first that you know will be rejected. Once they say no, immediately follow up with your real request. Their brain views the compromise as a favor and will accept it seventy percent more often."
            ),
            (
                "How to tell if someone is secretly lying to you in less than five seconds.",
                "Here is how professional interrogators spot a lie in real time. First: Notice their blink rate. The average human blinks fifteen to twenty times per minute. When someone is fabricating a story, cognitive load increases dramatically and their blink rate will drop to almost zero, followed by a rapid burst of blinking once they finish the sentence. Second: Watch their shoulders. Truthful statements are accompanied by natural, symmetrical micro-movements. If someone shrugs with only one shoulder while saying 'I swear I didn't do it,' their body is actively rejecting the lie they just spoke. Third: The Backward Chronology Test. If you suspect someone is lying about their alibi, casually ask them to tell the story backwards, starting from when they got home to when they left. A fabricated story is memorized forwards like a script; repeating it backwards is almost impossible without stumbling."
            )
        ]
        let picked = stories.randomElement()!
        return Story(
            title: picked.0,
            story: picked.1,
            author: "u/PsychMindset",
            upvotes: Int.random(in: 15000...42000),
            subreddit: "r/LifeProTips",
            topic: "Psychology"
        )
    }

    private func generateShowerThoughtsStory(prompt: String) -> Story {
        let stories = [
            (
                "Five shower thoughts that will completely break how you view reality.",
                "Here are five mind-bending facts that sound fake but are one hundred percent true. First: Your future self is watching you right now through your memories. Second: If you replace every wooden plank on a ship over ten years until none of the original wood remains, is it still the same ship? Every cell in your human body replaces itself every seven years, meaning you are physically not the same person you were seven years ago. Third: The brain is the only organ in the universe that named itself. Fourth: If human history was scaled to a single twenty-four-hour day, the entire industrial revolution, all of modern technology, airplanes, and smartphones happened in the last two seconds before midnight. Fifth: You have walked past dozens of people who will remember your face for the rest of their lives, and you will never know which ones."
            )
        ]
        let picked = stories.randomElement()!
        return Story(
            title: picked.0,
            story: picked.1,
            author: "u/DeepThoughtGalaxy",
            upvotes: Int.random(in: 11000...31000),
            subreddit: "r/Showerthoughts",
            topic: "Shower Thoughts"
        )
    }

    private func generateTrueCrimeStory(prompt: String) -> Story {
        let stories = [
            (
                "The genius heist of the Antwerp Diamond Center where fifty million was stolen without a single alarm.",
                "In February 2003, a team of Italian masterminds pulled off what criminologists call the most impossible heist in modern history. The Antwerp Diamond Vault was protected by ten layers of military-grade security: Doppler radar detectors, seismic motion sensors, an infrared heat curtain, magnetic field triggers, and a lock with over one hundred million possible combinations. Leonardo Notarbartolo spent thirty months renting an office in the building posing as an eccentric Italian jewelry merchant. On the night of the heist, the team bypassed the infrared sensors using ordinary women's hairspray to coat the thermal mirrors. They covered the light sensors with electrical tape, copied the foot-long key using silicone impression putty, and walked out with one hundred and twenty safe-deposit boxes filled with fifty million dollars in uncut diamonds. To this day, not a single diamond has ever been recovered."
            )
        ]
        let picked = stories.randomElement()!
        return Story(
            title: picked.0,
            story: picked.1,
            author: "u/HeistArchives",
            upvotes: Int.random(in: 21000...55000),
            subreddit: "r/UnresolvedMysteries",
            topic: "True Crime"
        )
    }

    // MARK: - On-Device AI Story Vibe & Voice Matching
    public func analyzeStoryVibe(story: String, title: String) -> AIMatch {
        let full = (title + " " + story).lowercased()

        let horrorKeywords = ["ghost", "stalker", "whisper", "creepy", "dark", "died", "blood", "basement", "footsteps", "shadow", "woods", "scream", "scary", "dead"]
        let dramaKeywords = ["aita", "asshole", "cheated", "divorce", "in-law", "boss", "fired", "stole", "lied", "entitled", "wedding", "sister", "husband", "wife", "family", "revenge"]
        let fastKeywords = ["police", "car", "speed", "crashed", "chase", "stolen", "caught", "heist", "run", "jump", "diamond", "emergency"]
        let smartKeywords = ["psychology", "trick", "mind", "fact", "brain", "universe", "secret", "millionaire", "hack", "algorithm", "code", "shower"]

        func countMatches(_ keys: [String]) -> Int {
            keys.reduce(0) { $0 + (full.contains($1) ? 1 : 0) }
        }

        let hScore = countMatches(horrorKeywords)
        let dScore = countMatches(dramaKeywords)
        let fScore = countMatches(fastKeywords)
        let sScore = countMatches(smartKeywords)

        if hScore >= max(dScore, fScore, sScore, 1) {
            return AIMatch(
                vibe: "Dark Suspense & Creepypasta",
                vibe_key: "horror",
                recommended_voice: "en-US-EricNeural",
                voice_name: "Eric (True Crime & Mystery)",
                recommended_rate: "+0%",
                recommended_color: "&H0000FF&",
                color_name: "Hot Coral Red",
                recommended_bg: "dark_cinematic",
                bg_name: "Dark Atmospheric Mystery",
                subtitle_style: "single",
                rationale: "Detected high suspense and tension words. Recommending deep pacing, crimson highlight, and atmospheric b-roll."
            )
        } else if fScore >= max(dScore, sScore, 1) {
            return AIMatch(
                vibe: "High-Octane Adrenaline",
                vibe_key: "action",
                recommended_voice: "en-US-GuyNeural",
                voice_name: "Guy (Energetic Viral)",
                recommended_rate: "+12%",
                recommended_color: "&H00FF00&",
                color_name: "Neon Lime Green",
                recommended_bg: "gta_stunts",
                bg_name: "GTA V Mega Ramp Stunts",
                subtitle_style: "single",
                rationale: "Action-packed narrative requires snappy pacing and high-energy GTA V Mega Ramp b-roll to maximize retention."
            )
        } else if sScore >= max(dScore, 1) {
            return AIMatch(
                vibe: "Satisfying & Mindbending",
                vibe_key: "smart",
                recommended_voice: "en-US-JennyNeural",
                voice_name: "Jenny (Natural Voice)",
                recommended_rate: "+8%",
                recommended_color: "&HFFFF00&",
                color_name: "Electric Cyan",
                recommended_bg: "satisfying_asmr",
                bg_name: "Satisfying Kinetic Sand & Soap",
                subtitle_style: "karaoke",
                rationale: "Educational or thought-provoking story matches perfectly with oddly satisfying ASMR footage and modern cyan captions."
            )
        } else {
            // Default Drama / AITA
            return AIMatch(
                vibe: "Petty Drama & Gossip",
                vibe_key: "drama",
                recommended_voice: "en-US-ChristopherNeural",
                voice_name: "Christopher (Deep Storyteller)",
                recommended_rate: "+8%",
                recommended_color: "&H00FFFF&",
                color_name: "TikTok Yellow",
                recommended_bg: "subway_surfers",
                bg_name: "Subway Surfers Fast Run",
                subtitle_style: "karaoke",
                rationale: "Relatable drama pairs with TikTok iconic yellow karaoke text and fast-paced Subway Surfers gameplay."
            )
        }
    }

    private func getFallbackStories(for subreddit: String) -> [Story] {
        return [
            generateAITAStory(prompt: ""),
            generateRevengeStory(prompt: ""),
            generateScaryStory(prompt: "")
        ]
    }
}
