import argparse
import asyncio
from app.video.generator import VideoGenerator
from app.scrapers.reddit import RedditScraper
from app.scrapers.quora import QuoraScraper
from app.scrapers.youtube import YouTubeScraper
from app.scrapers.ai_generator import AIViralStoryGenerator

def main():
    parser = argparse.ArgumentParser(description="Generate Viral TikTok Videos with AI Voice Matching & Auto-Scrubbed Backgrounds")
    parser.add_argument("--source", choices=["reddit", "quora", "youtube", "ai", "custom"], default="ai", help="Story source")
    parser.add_argument("--subreddit", default="AmItheAsshole", help="Subreddit name if source is reddit")
    parser.add_argument("--url", help="URL for reddit, quora, or youtube")
    parser.add_argument("--category", default="aita", help="AI story category (aita, revenge, confession, mystery)")
    parser.add_argument("--voice", default="auto", help="TTS Voice (or 'auto' for AI recommendation)")
    parser.add_argument("--rate", default="auto", help="TTS speed rate (or 'auto' for AI optimal pacing)")
    parser.add_argument("--background", default="auto", help="Background b-roll footage or 'auto' to scrub matching footage")
    parser.add_argument("--style", default="auto", choices=["auto", "karaoke", "single"], help="Subtitle style")
    parser.add_argument("--title", help="Custom title")
    parser.add_argument("--story", help="Custom story text")
    args = parser.parse_args()

    title = args.title or "Viral TikTok Story"
    story = args.story or ""

    if args.source == "reddit":
        scraper = RedditScraper()
        if args.url:
            post = scraper.scrape_post_url(args.url)
            if post:
                title, story = post["title"], post["story"]
        else:
            stories = scraper.search_reddit_stories(subreddit=args.subreddit)
            if stories:
                title, story = stories[0]["title"], stories[0]["story"]
    elif args.source == "quora":
        scraper = QuoraScraper()
        if args.url:
            post = scraper.scrape_url(args.url)
            if post:
                title, story = post["question"], post["story"]
        else:
            stories = scraper.get_curated_stories()
            if stories:
                title, story = stories[0]["question"], stories[0]["story"]
    elif args.source == "youtube":
        scraper = YouTubeScraper()
        if not args.url:
            print("Please provide --url for YouTube")
            return
        video = scraper.fetch_video_transcript(args.url)
        if video:
            title, story = video["title"], video["story"]
    elif args.source == "ai":
        gen = AIViralStoryGenerator()
        res = gen.generate_story(category=args.category)
        title, story = res["title"], res["story"]

    if not story:
        print("No story content found or specified.")
        return

    print(f"\n[StoryTeller CLI] Title: {title}")
    print(f"[StoryTeller CLI] Story words: {len(story.split())}")
    print(f"[StoryTeller CLI] Launching AI Video Pipeline with Auto-Match...")

    video_gen = VideoGenerator()
    result = asyncio.run(video_gen.generate_tiktok_video(
        title=title,
        story_text=story,
        voice=args.voice,
        rate=args.rate,
        background_id=args.background,
        subtitle_style=args.style,
        status_callback=lambda msg, pct: print(f"[{pct}%] {msg}")
    ))

    ai_match = result.get("ai_match", {})
    print("\n" + "=" * 55)
    print("🎬 FULLY AI-GENERATED TIKTOK VIDEO COMPLETE!")
    print(f"Path:          {result['video_path']}")
    print(f"Duration:      {result['duration']}s")
    print(f"Detected Vibe: {ai_match.get('vibe')}")
    print(f"Matched Voice: {ai_match.get('voice_name')} ({ai_match.get('rate')})")
    print(f"Scrubbed B-Roll:{ai_match.get('bg_name')}")
    print(f"Rationale:     {ai_match.get('rationale')}")
    print("\nTikTok Caption:\n" + result['caption'])
    print("=" * 55)

if __name__ == "__main__":
    main()
