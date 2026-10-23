import Foundation

public struct HookOption: Identifiable {
    public let id = UUID()
    public let style: String
    public let badge: String
    public let hookTitle: String
    public let hookOpening: String
    public let viralStrategy: String
}

public struct StoryParts {
    public let part1Title: String
    public let part1Story: String
    public let part2Title: String
    public let part2Story: String
    public let isSplittable: Bool
}

public class ViralStoryIntelligence {
    public static let shared = ViralStoryIntelligence()

    private init() {}

    // MARK: - AI Hook Doctor: 3 Proven Viral Formats
    public func generateViralHooks(title: String, story: String) -> [HookOption] {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanStory = story.trimmingCharacters(in: .whitespacesAndNewlines)

        // Detect themes
        let lower = (cleanTitle + " " + cleanStory).lowercased()
        let hasFamily = lower.contains("sister") || lower.contains("brother") || lower.contains("mom") || lower.contains("dad") || lower.contains("family") || lower.contains("wedding") || lower.contains("husband") || lower.contains("wife")
        let hasWork = lower.contains("boss") || lower.contains("manager") || lower.contains("job") || lower.contains("fired") || lower.contains("bonus") || lower.contains("company") || lower.contains("corporate")
        let hasMystery = lower.contains("monitor") || lower.contains("ghost") || lower.contains("creepy") || lower.contains("door") || lower.contains("night") || lower.contains("whisper") || lower.contains("house")
        let hasCrime = lower.contains("heist") || lower.contains("diamond") || lower.contains("stolen") || lower.contains("police") || lower.contains("robbery") || lower.contains("vault")

        // 1. Shock & Curiosity Hook
        let shockTitle: String
        let shockOpening: String
        if hasFamily {
            shockTitle = "The 10-second video that completely destroyed my sister's wedding."
            shockOpening = "I never thought three years of keeping my mouth shut would end like this, but when she called the coordinator a murderer in front of two hundred guests, I lost all patience."
        } else if hasWork {
            shockTitle = "How I got my CEO to fire my boss in under 8 seconds."
            shockOpening = "If my manager hadn't stolen our entire departmental bonus pool, he would still have his two hundred thousand dollar a year job today."
        } else if hasMystery {
            shockTitle = "Whatever you do, never buy a vintage baby monitor at a garage sale."
            shockOpening = "At 3:14 AM on Thursday, the static crackled to life in my daughter's room, but the sound coming out of the receiver was impossible."
        } else if hasCrime {
            shockTitle = "The $50 million diamond vault heist that used an ordinary can of hairspray."
            shockOpening = "They bypassed seismic sensors, Doppler radar, and infrared heat curtains, and the police still have no idea where the diamonds went."
        } else {
            shockTitle = "Wait until the very end, because nobody saw this twist coming."
            shockOpening = "I used to think people were exaggerating when they told me stories like this, until the exact same thing happened to me yesterday."
        }

        // 2. POV / Immersive Format (Top TikTok Trend)
        let povTitle: String
        let povOpening: String
        if hasFamily {
            povTitle = "POV: You find out your sister's 3-year allergy was a lie."
            povOpening = "POV: You walk into a random Italian trattoria on your lunch break and catch the one person who forced the entire family to eat bland food inhaling garlic bread."
        } else if hasWork {
            povTitle = "POV: Your manager steals your bonus so you automate his career away."
            povOpening = "POV: You open Python after hours, write five automation scripts, and wait for the executive board meeting to casually show the VP your screen."
        } else if hasMystery {
            povTitle = "POV: The baby monitor turns on, but there are no batteries inside."
            povOpening = "POV: You hear a rocking chair creaking on wooden floorboards in your daughter's carpeted bedroom at three in the morning."
        } else {
            povTitle = "POV: You finally expose the one person who thought they were untouchable."
            povOpening = "POV: You have the exact timestamped evidence, and the moment has finally arrived to lay it all out on the table."
        }

        // 3. Moral Dilemma / Judgment Hook (Drives 10x Comment Section Arguments)
        let dilemmaTitle: String
        let dilemmaOpening: String
        if hasFamily {
            dilemmaTitle = "Am I the jerk for playing this video at my sister's wedding?"
            dilemmaOpening = "Half the guests walked out, my mother hasn't spoken to me in 48 hours, but I need you to hear the full story before you judge me."
        } else if hasWork {
            dilemmaTitle = "Was I wrong for destroying my boss's career over a bonus?"
            dilemmaOpening = "HR called my actions ruthless, but he took fifteen thousand dollars straight out of our pockets. Tell me in the comments if I crossed the line."
        } else {
            dilemmaTitle = "Listen to the full story before you decide if I was wrong."
            dilemmaOpening = "Everyone in my circle is divided right down the middle on this, and I genuinely need an unbiased third party to tell me the truth."
        }

        return [
            HookOption(
                style: "Curiosity & Shock",
                badge: "🔥 89% RETENTION",
                hookTitle: shockTitle,
                hookOpening: shockOpening,
                viralStrategy: "Creates an instant high-stakes curiosity gap that stops viewers from scrolling in the first 2 seconds."
            ),
            HookOption(
                style: "POV Immersion",
                badge: "👁️ TIKTOK VIRAL",
                hookTitle: povTitle,
                hookOpening: povOpening,
                viralStrategy: "Puts the viewer directly in the protagonist's shoes, triggering mirror neurons and higher shares."
            ),
            HookOption(
                style: "Moral Dilemma",
                badge: "💬 5X COMMENTS",
                hookTitle: dilemmaTitle,
                hookOpening: dilemmaOpening,
                viralStrategy: "Triggers strong debate in the comments section, signaling the algorithm to push to the FYP."
            )
        ]
    }

    // MARK: - Multi-Part Story Splitter (Part 1 & Part 2 Cliffhangers)
    public func splitStoryIntoParts(title: String, story: String) -> StoryParts {
        let words = story.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count < 80 {
            return StoryParts(
                part1Title: title,
                part1Story: story,
                part2Title: "",
                part2Story: "",
                isSplittable: false
            )
        }

        // Find split point around 55% of story at sentence boundary
        let sentences = story.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let targetWordIndex = Int(Double(words.count) * 0.55)
        var cumulativeWords = 0
        var splitSentenceIndex = max(1, sentences.count / 2)

        for (idx, sentence) in sentences.enumerated() {
            let sWords = sentence.split(whereSeparator: \.isWhitespace).count
            cumulativeWords += sWords
            if cumulativeWords >= targetWordIndex {
                splitSentenceIndex = idx
                break
            }
        }

        let part1Sentences = sentences[0...splitSentenceIndex].joined(separator: ". ") + "."
        let part2Sentences = sentences[(splitSentenceIndex + 1)...].joined(separator: ". ") + "."

        let cliffhanger = " What happened next left everyone completely speechless... Follow and check my profile for Part 2! ➡️"
        let part1Final = part1Sentences + cliffhanger
        let part2Final = "Welcome back to Part 2! Here is what happened next: " + part2Sentences

        let cleanBaseTitle = title.replacingOccurrences(of: "(Part 1)", with: "").replacingOccurrences(of: "(Part 2)", with: "").trimmingCharacters(in: .whitespaces)

        return StoryParts(
            part1Title: "\(cleanBaseTitle) (Part 1) 🔥",
            part1Story: part1Final,
            part2Title: "\(cleanBaseTitle) (Part 2 - The Conclusion) 💥",
            part2Story: part2Final,
            isSplittable: true
        )
    }

    // MARK: - Trending SEO Hashtags
    public func generateHashtags(title: String, story: String) -> [String] {
        let combined = (title + " " + story).lowercased()
        var tags = ["#StoryTime", "#TikTokStories", "#ViralTikTok", "#Shorts"]

        if combined.contains("sister") || combined.contains("wedding") || combined.contains("aita") || combined.contains("family") {
            tags.append(contentsOf: ["#AITA", "#RedditStories", "#FamilyDrama", "#WeddingDrama", "#Exposed"])
        } else if combined.contains("boss") || combined.contains("job") || combined.contains("bonus") || combined.contains("work") {
            tags.append(contentsOf: ["#PettyRevenge", "#MaliciousCompliance", "#WorkTok", "#CorporateLife", "#InstantKarma"])
        } else if combined.contains("monitor") || combined.contains("creepy") || combined.contains("mystery") {
            tags.append(contentsOf: ["#CreepyStories", "#TrueHorror", "#Unexplained", "#Mystery", "#PlotTwist"])
        } else if combined.contains("heist") || combined.contains("diamond") || combined.contains("crime") {
            tags.append(contentsOf: ["#TrueCrime", "#HeistStory", "#Mastermind", "#Unsolved", "#CrimeTok"])
        } else {
            tags.append(contentsOf: ["#RedditReadings", "#CrazyStory", "#DidThisHappen", "#PlotTwist"])
        }

        return Array(tags.prefix(8))
    }
}
