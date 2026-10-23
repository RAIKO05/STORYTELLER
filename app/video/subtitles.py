from pathlib import Path
from typing import List, Dict
from app.utils.helpers import format_time_ass

class SubtitleGenerator:
    """
    Generates dynamic TikTok-style karaoke ASS subtitles
    with custom highlighting, customizable fonts, outlines, and mobile-safe margins.
    """

    def _build_ass_header(
        self,
        font_name: str = "Arial Black",
        font_size: int = 70,
        margin_v: int = 650,
        outline_width: int = 6,
        shadow_width: int = 3
    ) -> str:
        single_size = int(font_size * 1.15)
        return f"""[Script Info]
Title: TikTok Viral Subtitles
ScriptType: v4.00+
WrapStyle: 0
ScaledBorderAndShadow: yes
YCbCr Matrix: None
PlayResX: 1080
PlayResY: 1920

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: TikTokKaraoke,{font_name},{font_size},&H00FFFFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,{outline_width},{shadow_width},2,60,60,{margin_v},1
Style: TikTokSingle,{font_name},{single_size},&H0000FFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,{outline_width + 1},{shadow_width + 1},2,60,60,{margin_v},1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

    def generate_ass(
        self,
        words: List[Dict],
        output_path: Path,
        style_mode: str = "karaoke",  # 'karaoke' or 'single' or 'clean'
        words_per_group: int = 3,
        highlight_color: str = "&H00FFFF&", # Yellow in ASS BGR
        font_name: str = "Arial Black",
        font_size: int = 70,
        margin_v: int = 650,
        outline_width: int = 6,
        shadow_width: int = 3,
        text_case: str = "upper"
    ) -> Path:
        """
        Creates an ASS subtitle file from timed words with full typography customization.
        """
        dialogue_lines = []
        header = self._build_ass_header(
            font_name=font_name,
            font_size=font_size,
            margin_v=margin_v,
            outline_width=outline_width,
            shadow_width=shadow_width
        )

        if not words:
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(header)
            return output_path

        def format_word(w_str: str) -> str:
            if text_case == "upper":
                return w_str.upper()
            elif text_case == "title":
                return w_str.capitalize()
            return w_str

        if style_mode == "single":
            # 1 word at a time, high velocity
            for w in words:
                start_str = format_time_ass(w["start"])
                end_str = format_time_ass(w["end"])
                clean_w = format_word(w["word"])
                dialogue_lines.append(
                    f"Dialogue: 0,{start_str},{end_str},TikTokSingle,,0,0,0,,{clean_w}"
                )
        else:
            # Grouped karaoke style (e.g. 2-3 words per phrase)
            for i in range(0, len(words), words_per_group):
                group = words[i:i + words_per_group]

                # For each word in the group, create a dialogue line with that word highlighted
                for current_idx, active_word in enumerate(group):
                    w_start_str = format_time_ass(active_word["start"])
                    w_end_str = format_time_ass(active_word["end"])

                    formatted_words = []
                    for idx, w in enumerate(group):
                        word_text = format_word(w["word"])
                        if idx == current_idx:
                            formatted_words.append(f"{{\\c{highlight_color}\\b1}}{word_text}{{\\c&H00FFFFFF&\\b0}}")
                        else:
                            formatted_words.append(word_text)

                    group_text = " ".join(formatted_words)
                    dialogue_lines.append(
                        f"Dialogue: 0,{w_start_str},{w_end_str},TikTokKaraoke,,0,0,0,,{group_text}"
                    )

        content = header + "\n".join(dialogue_lines) + "\n"
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(content)

        return output_path
