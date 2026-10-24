# tests/test_security_shield.py
import unittest
from fastapi.testclient import TestClient
from app.web.api import app
from app.security.shield import generate_server_attestation, firewall

client = TestClient(app)

class SecurityShieldTestCase(unittest.TestCase):
    def setUp(self):
        # Reset firewall quarantine state between unit tests
        firewall.quarantined_ips.clear()
        firewall.request_history.clear()
    def test_anti_piracy_gate_blocks_unsigned_rendering(self):
        """Unsigned requests to high-value routes are rejected with 403."""
        res = client.post("/api/video/generate", json={
            "title": "Unsigned Render",
            "story": "A story text without attestation headers."
        })
        self.assertEqual(res.status_code, 403)
        self.assertIn("Anti-Piracy Gate", res.json().get("security_alert", ""))

    def test_attestation_handshake_rejects_pirated_bundle(self):
        """Requests with pirated/re-signed bundle IDs are blocked."""
        res = client.post("/api/security/handshake", json={
            "bundle_id": "com.pirated.crackedapp"
        })
        self.assertEqual(res.status_code, 403)
        self.assertIn("Integrity Violation", res.json()["detail"])

    def test_attestation_handshake_accepts_authorized_client(self):
        """Authorized bundle ID receives valid cryptographic tokens."""
        res = client.post("/api/security/handshake", json={
            "bundle_id": "com.storyteller.app"
        })
        self.assertEqual(res.status_code, 200)
        tokens = res.json()["tokens"]
        self.assertIn("X-App-Signature", tokens)
        self.assertEqual(tokens["X-Bundle-ID"], "com.storyteller.app")

    def test_ssrf_blocking_on_scrapers(self):
        """Disallowed domains and private IP ranges are blocked."""
        res = client.post("/api/reddit/scrape-url", json={"url": "https://malicious-site.com/exploit"})
        self.assertEqual(res.status_code, 403)
        self.assertIn("not in the authorized content whitelist", res.json()["detail"])

        res2 = client.post("/api/reddit/scrape-url", json={"url": "http://127.0.0.1:8000/admin"})
        self.assertIn(res2.status_code, (400, 403))

    def test_input_guardrail_blocks_command_injection_and_null_bytes(self):
        """Signed requests with dangerous command payloads are rejected with 400."""
        headers = generate_server_attestation("com.storyteller.app", "/api/video/generate")
        
        # Command injection attempt
        res = client.post(
            "/api/video/generate",
            json={"title": "Test $(calc.exe)", "story": "Normal story content here."},
            headers=headers
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("Malicious code execution", res.json()["detail"])

        # Null byte attack attempt (with fresh nonce to prevent replay detection)
        headers2 = generate_server_attestation("com.storyteller.app", "/api/video/generate")
        res2 = client.post(
            "/api/video/generate",
            json={"title": "Safe Title", "story": "Story with \x00 null byte."},
            headers=headers2
        )
        self.assertEqual(res2.status_code, 400)
        self.assertIn("Null byte", res2.json()["detail"])

    def test_behavioral_firewall_anomaly_quarantine(self):
        """Probing for exploit paths results in immediate 429 quarantine."""
        res = client.get("/api/presets?scan=.env")
        self.assertEqual(res.status_code, 429)

    def test_ass_subtitle_header_injection_sanitization(self):
        """ASS header builder strips newlines and restricts font names."""
        from app.video.subtitles import SubtitleGenerator
        gen = SubtitleGenerator()
        malicious_font = "Arial Black\nStyle: InjectedStyle,Comic Sans,100...\n[Events]\nDialogue: 0"
        header = gen._build_ass_header(font_name=malicious_font)
        self.assertNotIn("\nStyle: InjectedStyle", header)
        self.assertIn("Style: TikTokKaraoke,Arial BlackStyle InjectedStyleComic Sans100EventsDialogue 0", header)

    def test_expiring_job_store_eviction(self):
        """Job store evicts oldest jobs when reaching max capacity and prunes expired ones."""
        from app.web.api import ExpiringJobStore
        store = ExpiringJobStore(max_entries=3, ttl_seconds=1)
        store["job_1"] = {"val": 1}
        store["job_2"] = {"val": 2}
        store["job_3"] = {"val": 3}
        store["job_4"] = {"val": 4} # Should evict job_1

        self.assertNotIn("job_1", store)
        self.assertIn("job_4", store)
        self.assertEqual(store["job_4"]["val"], 4)

if __name__ == "__main__":
    unittest.main()
