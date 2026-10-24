"""
StoryTeller Security Architecture Package
Integrates Context-Aware Input Guardrails, Anti-Piracy Attestation, and Behavioral Firewall.
"""
from app.security.shield import (
    SecurityShield,
    validate_story_input,
    validate_scraper_url,
    sanitize_upload_filename,
    verify_app_attestation
)

__all__ = [
    "SecurityShield",
    "validate_story_input",
    "validate_scraper_url",
    "sanitize_upload_filename",
    "verify_app_attestation"
]
