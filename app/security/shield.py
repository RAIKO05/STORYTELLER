# app/security/shield.py
"""
CORE DOMAIN 1: AUTOMATED SECURITY & ANTI-PIRACY SHIELDING
Provides:
1. Context-Aware Input Guardrails (Command/Script/ASS Injection Prevention & SSRF Firewall)
2. Integrity & Anti-Piracy Attestation Handshake (HMAC-SHA256 Token & Bundle Verification)
3. Behavioral Firewall & Real-Time Anomaly Detection (Rate Limiting & Exploit Quarantine)
"""

import os
import re
import time
import hmac
import hashlib
import ipaddress
import socket
from typing import Optional, Set, Dict, Tuple
from urllib.parse import urlparse
from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

# Shared Security Secret (Cryptographic salt for Client-Server Attestation)
APP_SECURITY_SECRET = os.getenv("STORYTELLER_SECURITY_SECRET", "st_sec_k98f21903ba8d7e6c412f901ab73c").encode("utf-8")
AUTHORIZED_BUNDLE_ID = "com.storyteller.app"
ALLOWED_SCRAPER_DOMAINS = {
    "reddit.com", "www.reddit.com", "redd.it", "old.reddit.com",
    "quora.com", "www.quora.com",
    "youtube.com", "www.youtube.com", "youtu.be", "m.youtube.com"
}

# -------------------------------------------------------------
# 1. CONTEXT-AWARE INPUT GUARDRAILS
# -------------------------------------------------------------

DANGEROUS_COMMAND_PATTERNS = [
    re.compile(r"(\$|\`)\(.*\)", re.IGNORECASE),          # Command substitution: $(cmd) or `cmd`
    re.compile(r"\b(rm|cat|kill|shutdown|chmod|chown)\b\s+-[a-z0-9]", re.IGNORECASE),
    re.compile(r";\s*(rm|del|shutdown|bash|sh|cmd|powershell)\b", re.IGNORECASE),
    re.compile(r"\|\|\s*(rm|del|shutdown|bash|sh|cmd)\b", re.IGNORECASE),
    re.compile(r"<\s*script\b[^>]*>", re.IGNORECASE),      # XSS Payloads
    re.compile(r"javascript:\s*", re.IGNORECASE),
]

ASS_INJECTION_PATTERN = re.compile(r"\{\\[a-zA-Z0-9_]+(?:\(.*?\))?\}")  # Advanced SubStation Alpha tag overrides

def sanitize_text_field(value: str, max_length: int = 15000, field_name: str = "Input") -> str:
    """
    Validates and sanitizes text to block command injection, code execution,
    null-byte attacks, and malicious subtitle formatting exploits.
    """
    if not value:
        return ""
    
    # Check null bytes
    if "\x00" in value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Security Alert: Null byte sequence detected in {field_name}."
        )

    # Check maximum length threshold to mitigate memory exhaustion DoS
    if len(value) > max_length:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name} exceeds maximum permitted length of {max_length} characters."
        )

    # Check dangerous command injection and script patterns
    for pattern in DANGEROUS_COMMAND_PATTERNS:
        if pattern.search(value):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Security Alert: Malicious code execution or command injection payload blocked in {field_name}."
            )

    # Strip malicious ASS subtitle tags that could override formatting or break rendering engine
    clean_value = ASS_INJECTION_PATTERN.sub("", value)
    
    # Normalize carriage returns and controls
    clean_value = re.sub(r"[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]", "", clean_value)
    return clean_value.strip()

def validate_story_input(title: str, story: str) -> Tuple[str, str]:
    """
    Enforces strict guardrails on video generation scripts.
    """
    clean_title = sanitize_text_field(title, max_length=250, field_name="Story Title")
    clean_story = sanitize_text_field(story, max_length=15000, field_name="Story Script")
    if not clean_story:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Story text cannot be empty.")
    return clean_title, clean_story

def validate_scraper_url(raw_url: str) -> str:
    """
    Blocks Server-Side Request Forgery (SSRF) and metadata service harvesting.
    Ensures URL targets strictly authorized public domains and resolves to safe public IPs.
    """
    clean_url = raw_url.strip()
    parsed = urlparse(clean_url)

    if parsed.scheme.lower() not in ("http", "https"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Security Violation: Only secure HTTP/HTTPS protocol schemes are permitted."
        )

    hostname = (parsed.hostname or "").lower()
    if not hostname:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Security Violation: Missing target hostname in URL."
        )

    # Domain Whitelist Check
    domain_match = False
    for allowed in ALLOWED_SCRAPER_DOMAINS:
        if hostname == allowed or hostname.endswith("." + allowed):
            domain_match = True
            break

    if not domain_match:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Security Policy: Target domain '{hostname}' is not in the authorized content whitelist."
        )

    # DNS Resolution & SSRF Private IP Prevention
    try:
        resolved_ips = socket.getaddrinfo(hostname, None)
        for item in resolved_ips:
            ip_str = item[4][0]
            ip_obj = ipaddress.ip_address(ip_str)
            if ip_obj.is_private or ip_obj.is_loopback or ip_obj.is_link_local or ip_obj.is_reserved or ip_obj.is_multicast:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Security Violation: Target host resolves to an unroutable or private IP range ({ip_str})."
                )
    except socket.gaierror:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unable to resolve host: {hostname}"
        )

    return clean_url

def sanitize_upload_filename(raw_filename: str, allowed_extensions: Set[str]) -> str:
    """
    Prevents path traversal, shell execution via filename, and file extension spoofing.
    """
    base_name = os.path.basename(raw_filename)
    # Strip any directory separators or parent traversal
    clean_name = re.sub(r"[\/\\]", "", base_name)
    clean_name = re.sub(r"\.\.+", ".", clean_name)
    
    # Restrict to safe alphanumeric characters, underscores, hyphens and dot
    clean_name = re.sub(r"[^a-zA-Z0-9_\.-]", "_", clean_name)

    ext = os.path.splitext(clean_name)[1].lower()
    if ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File extension '{ext}' is prohibited. Permitted extensions: {', '.join(allowed_extensions)}"
        )

    # Prevent hidden files
    if clean_name.startswith("."):
        clean_name = "upload_" + clean_name.lstrip(".")

    return clean_name

# -------------------------------------------------------------
# 2. INTEGRITY & ANTI-PIRACY ATTESTATION HANDSHAKE
# -------------------------------------------------------------

# In-memory nonce cache to protect against replay attacks (cleared periodically)
SEEN_NONCES: Dict[str, float] = {}

def verify_app_attestation(
    signature: Optional[str],
    bundle_id: Optional[str],
    timestamp_str: Optional[str],
    nonce: Optional[str],
    path: str
) -> bool:
    """
    Validates cryptographic signature and application attestation headers.
    Confirms the caller is an untampered StoryTeller client running with authorized Bundle ID.
    """
    if not signature or not timestamp_str or not nonce:
        # Missing attestation headers
        return False

    try:
        req_time = float(timestamp_str)
    except ValueError:
        return False

    # 1. Freshness window check (5 minutes max clock drift)
    now = time.time()
    if abs(now - req_time) > 300:
        return False

    # 2. Replay attack protection via nonce deduplication
    current_time = time.time()
    # Prune nonces older than 10 minutes
    expired_keys = [k for k, t in SEEN_NONCES.items() if current_time - t > 600]
    for k in expired_keys:
        SEEN_NONCES.pop(k, None)

    if nonce in SEEN_NONCES:
        return False # Replay attempt blocked!
    SEEN_NONCES[nonce] = current_time

    # 3. Bundle Identifier Integrity
    if bundle_id != AUTHORIZED_BUNDLE_ID and bundle_id != "com.storyteller.web":
        return False

    # 4. HMAC-SHA256 Signature Verification
    # Message format: bundle_id:timestamp:nonce:path
    message = f"{bundle_id}:{timestamp_str}:{nonce}:{path}".encode("utf-8")
    expected_sig = hmac.new(APP_SECURITY_SECRET, message, hashlib.sha256).hexdigest()

    return hmac.compare_digest(signature.lower(), expected_sig.lower())

def generate_server_attestation(bundle_id: str, path: str) -> Dict[str, str]:
    """
    Generates server-side attestation payload for initial handshake.
    """
    timestamp = str(int(time.time()))
    nonce = hashlib.sha256(f"{time.time()}:{os.urandom(16).hex()}".encode()).hexdigest()[:16]
    message = f"{bundle_id}:{timestamp}:{nonce}:{path}".encode("utf-8")
    sig = hmac.new(APP_SECURITY_SECRET, message, hashlib.sha256).hexdigest()
    return {
        "X-App-Signature": sig,
        "X-Bundle-ID": bundle_id,
        "X-Timestamp": timestamp,
        "X-Nonce": nonce
    }

# -------------------------------------------------------------
# 3. BEHAVIORAL FIREWALL & REAL-TIME ANOMALY DETECTION
# -------------------------------------------------------------

class BehavioralFirewall:
    """
    In-memory adaptive rate limiter and heuristic anomaly detector.
    Blocks automated scraper bots, brute-force exploits, and unauthorized high-frequency requests.
    """
    def __init__(self):
        # Client IP -> list of timestamps
        self.request_history: Dict[str, list] = {}
        # Client IP -> ban expiration timestamp
        self.quarantined_ips: Dict[str, float] = {}

        # Heuristic bot / malicious exploit signatures
        self.exploit_patterns = [
            re.compile(r"(\.env|wp-login|phpinfo|\.git\/|etc\/passwd|\/proc\/self)", re.IGNORECASE),
            re.compile(r"(\bunion\s+select\b|\bselect\s+.*?\s+from\b|--|;\s*drop\b)", re.IGNORECASE),
            re.compile(r"(cgi-bin|web-inf|\/actuator\/|\/console\/)", re.IGNORECASE)
        ]

    def is_quarantined(self, client_ip: str) -> Tuple[bool, int]:
        now = time.time()
        if client_ip in self.quarantined_ips:
            exp = self.quarantined_ips[client_ip]
            if now < exp:
                return True, int(exp - now)
            else:
                del self.quarantined_ips[client_ip]
        return False, 0

    def quarantine(self, client_ip: str, duration_sec: int = 900):
        self.quarantined_ips[client_ip] = time.time() + duration_sec

    def check_request(self, client_ip: str, path: str, query: str = "") -> Tuple[bool, Optional[str]]:
        now = time.time()

        # 1. Check existing quarantine
        banned, remaining = self.is_quarantined(client_ip)
        if banned:
            return False, f"Behavioral Quarantine Active. Automated probing detected. Retry in {remaining}s."

        # 2. Heuristic Anomaly Detection
        full_target = f"{path}?{query}" if query else path
        for pat in self.exploit_patterns:
            if pat.search(full_target):
                self.quarantine(client_ip, duration_sec=1800) # 30 min ban for active exploit probing
                return False, "Security Threat Detected: Malicious URL exploit signature quarantined."

        # 3. Adaptive Rate Limiting
        history = self.request_history.get(client_ip, [])
        # Retain last 60 seconds
        cutoff = now - 60.0
        history = [t for t in history if t > cutoff]

        # Determine threshold based on endpoint sensitivity
        if "/api/video/generate" in path:
            limit = 6 # Max 6 heavy video jobs per minute
        elif "/upload" in path:
            limit = 12 # Max 12 uploads per minute
        elif "/scrape" in path or "/stories" in path:
            limit = 20 # Max 20 scrape calls per minute
        else:
            limit = 80 # General API rate limit

        if len(history) >= limit:
            self.quarantine(client_ip, duration_sec=180) # 3 min cooling period
            return False, f"Rate Limit Exceeded: Maximum {limit} req/min reached for this route."

        history.append(now)
        self.request_history[client_ip] = history
        return True, None

# Singleton Firewall Instance
firewall = BehavioralFirewall()

# -------------------------------------------------------------
# 4. FASTAPI SECURITY SHIELD MIDDLEWARE
# -------------------------------------------------------------

class SecurityShieldMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host if request.client else "127.0.0.1"
        path = request.url.path

        # Static assets and root HTML bypass rate limiter
        if path.startswith("/static") or path == "/" or path.startswith("/outputs"):
            return await call_next(request)

        # 1. Behavioral Firewall Inspection
        allowed, reason = firewall.check_request(
            client_ip=client_ip,
            path=path,
            query=str(request.url.query)
        )
        if not allowed:
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={"status": "error", "security_alert": reason},
                headers={"Retry-After": "180"}
            )

        # 2. Optional Anti-Piracy Attestation Handshake for Sensitive Operations
        # High value endpoints: Video Rendering and Story Generation
        if path in ("/api/video/generate", "/api/ai/generate-story"):
            sig = request.headers.get("X-App-Signature")
            bundle_id = request.headers.get("X-Bundle-ID")
            timestamp = request.headers.get("X-Timestamp")
            nonce = request.headers.get("X-Nonce")
            origin = request.headers.get("Origin") or request.headers.get("Referer")

            # Allow local Web Studio UI if originating from local host, otherwise require cryptographic signature
            is_local_web = origin and ("localhost" in origin or "127.0.0.1" in origin or "192.168." in origin)
            
            if not is_local_web:
                if not verify_app_attestation(sig, bundle_id, timestamp, nonce, path):
                    return JSONResponse(
                        status_code=status.HTTP_403_FORBIDDEN,
                        content={
                            "status": "error",
                            "security_alert": "Anti-Piracy Gate: Unauthorized client signature, tampered binary, or forged bundle ID."
                        }
                    )

        response = await call_next(request)
        
        # Inject Modern Security Headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        
        return response

class SecurityShield:
    """Convenience facade for direct route validations."""
    @staticmethod
    def validate_story(title: str, story: str) -> Tuple[str, str]:
        return validate_story_input(title, story)

    @staticmethod
    def validate_url(url: str) -> str:
        return validate_scraper_url(url)

    @staticmethod
    def sanitize_filename(filename: str, allowed_exts: Set[str]) -> str:
        return sanitize_upload_filename(filename, allowed_exts)
