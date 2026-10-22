from pathlib import Path
from typing import List, Dict
from app.utils.helpers import format_time_ass

class SubtitleGenerator:
    """
    Generates dynamic TikTok-style karaoke ASS subtitles
    with custom highlighting, thick outlines, and mobile-safe margins.
    """
    
    ASS_HEADER_TEMPLATE = """[Script Info]
Title: TikTok Viral Subtitles
ScriptType: v4.00+
WrapStyle: 0
ScaledBorderAndShadow: yes
YCbCr Matrix: None
PlayResX: 1080
PlayResY: 1920

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: TikTokKaraoke,Arial Black,70,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,6,3,2,60,60,650,1
Style: TikTokSingle,Arial Black,80,&H0000FFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,7,4,2,60,60,650,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

    def generate_ass(
        self,
        words: List[Dict],
        output_path: Path,
        style_mode: str = "karaoke",  # 'karaoke' or 'single' or 'clean'
        words_per_group: int = 3,
        highlight_color: str = "&H00FFFF&" # Yellow in ASS BGR
    ) -> Path:
        """
        Creates an ASS subtitle file from timed words.
        """
        dialogue_lines = []
        
        if not words:
            # Empty subtitle
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(self.ASS_HEADER_TEMPLATE)
            return output_path

        if style_mode == "single":
            # 1 word at a time, high velocity
            for w in words:
                start_str = format_time_ass(w["start"])
                end_str = format_time_ass(w["end"])
                clean_w = w["word"].upper()
                dialogue_lines.append(
                    f"Dialogue: 0,{start_str},{end_str},TikTokSingle,,0,0,0,,{clean_w}"
                )
        else:
            # Grouped karaoke style (e.g. 2-3 words per phrase)
            # Group words in chunks of `words_per_group`
            for i in range(0, len(words), words_per_group):
                group = words[i:i + words_per_group]
                group_start = group[0]["start"]
                group_end = group[-1]["end"]

                # For each word in the group, create a dialogue line with that word highlighted
                for current_idx, active_word in enumerate(group):
                    w_start_str = format_time_ass(active_word["start"])
                    w_end_str = format_time_ass(active_word["end"])

                    # Construct text with active word highlighted
                    formatted_words = []
                    for idx, w in enumerate(group):
                        word_text = w["word"].upper()
                        if idx == current_idx:
                            formatted_words.append(f"{{\\c{highlight_color}\\b1}}{word_text}{{\\c&H00FFFFFF&\\b0}}")
                        else:
                            formatted_words.append(word_text)

                    group_text = " ".join(formatted_words)
                    dialogue_lines.append(
                        f"Dialogue: 0,{w_start_str},{w_end_str},TikTokKaraoke,,0,0,0,,{group_text}"
                    )

        content = self.ASS_HEADER_TEMPLATE + "\n".join(dialogue_lines) + "\n"
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(content)

        return output_path
