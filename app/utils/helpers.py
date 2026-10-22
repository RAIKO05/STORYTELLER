import re
import unicodedata

def clean_text_for_tts(text: str) -> str:
    """
    Cleans up story text, expands acronyms, removes markdown links,
    and formats for clear, engaging text-to-speech pronunciation.
    """
    if not text:
        return ""
    
    # Remove markdown links [text](url) -> text
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    # Remove raw URLs
    text = re.sub(r'http\S+', '', text)
    
    # Common Reddit abbreviations expansion
    replacements = [
        (r'\bAITA\b', 'Am I the bad guy'),
        (r'\bWIBTA\b', 'Would I be the bad guy'),
        (r'\bTIFU\b', 'Today I messed up'),
        (r'\bTL;?DR\b', 'In short,'),
        (r'\bOP\b', 'original poster'),
        (r'\bSO\b', 'significant other'),
        (r'\bMIL\b', 'mother-in-law'),
        (r'\bFIL\b', 'father-in-law'),
        (r'\bSIL\b', 'sister-in-law'),
        (r'\bBIL\b', 'brother-in-law'),
        (r'\bAFAIK\b', 'as far as I know'),
        (r'\bIDK\b', 'I do not know'),
        (r'\bTBH\b', 'to be honest'),
        (r'\bIMO\b', 'in my opinion'),
        (r'\bIMHO\b', 'in my humble opinion'),
        (r'\bETA\b', 'edited to add:'),
        (r'\bUpdate:\b', 'Here is the update:'),
    ]
    for pattern, rep in replacements:
        text = re.sub(pattern, rep, text, flags=re.IGNORECASE)

    # Remove markdown formatting: bold, italic, strikethrough, headers, quotes
    text = re.sub(r'\*\*(.*?)\*\*', r'\1', text)
    text = re.sub(r'\*(.*?)\*', r'\1', text)
    text = re.sub(r'~~(.*?)~~', r'', text)
    text = re.sub(r'^#+\s*', '', text, flags=re.MULTILINE)
    text = re.sub(r'^>\s*', '', text, flags=re.MULTILINE)

    # Normalize whitespace
    text = re.sub(r'[\r\n]+', ' ', text)
    text = re.sub(r'\s{2,}', ' ', text)

    return text.strip()

def format_time_ass(seconds: float) -> str:
    """Format seconds into ASS timestamp: H:MM:SS.cs"""
    if seconds < 0:
        seconds = 0
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    cs = int(round((seconds - int(seconds)) * 100))
    if cs >= 100:
        cs = 99
    return f"{hrs}:{mins:02d}:{secs:02d}.{cs:02d}"

def format_time_srt(seconds: float) -> str:
    """Format seconds into SRT timestamp: HH:MM:SS,mmm"""
    if seconds < 0:
        seconds = 0
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    if millis >= 1000:
        millis = 999
    return f"{hrs:02d}:{mins:02d}:{secs:02d},{millis:03d}"

def slugify(text: str, max_length: int = 40) -> str:
    """Convert text into clean filesystem slug."""
    text = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode('ascii')
    text = re.sub(r'[^\w\s-]', '', text).strip().lower()
    text = re.sub(r'[-\s]+', '_', text)
    return text[:max_length]
