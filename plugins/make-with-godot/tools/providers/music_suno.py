"""Suno BGM Provider (기본)"""

import os
import json
import time
import urllib.request
import urllib.error
from . import MusicProvider


class SunoMusicProvider(MusicProvider):

    def __init__(self):
        self.api_key = os.environ.get("SUNO_API_KEY")
        if not self.api_key:
            raise ValueError("SUNO_API_KEY environment variable required")
        self.base_url = "https://apibox.erweima.ai/api/v1/generate"

    def generate_bgm(self, prompt: str, duration: int = 30,
                     genre: str = "") -> bytes:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        full_prompt = prompt
        if genre:
            full_prompt = f"[Genre: {genre}] {prompt}"

        payload = {
            "prompt": full_prompt,
            "customMode": False,
            "instrumental": True,  # 게임 BGM은 보컬 없음
            "model": "V4"
        }

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self.base_url,
            data=data,
            headers=headers,
            method="POST"
        )

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"Suno API error {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}") from e

        task_id = result.get("data", {}).get("taskId")
        if not task_id:
            raise RuntimeError(f"No task ID in Suno response: {result}")

        # 폴링 — Suno 생성은 시간이 걸림
        for _ in range(120):
            status_url = f"https://apibox.erweima.ai/api/v1/generate/record-info?taskId={task_id}"
            req = urllib.request.Request(status_url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as resp:
                status = json.loads(resp.read().decode("utf-8"))

            records = status.get("data", {}).get("response", {}).get("sunoData", [])
            if records and records[0].get("audioUrl"):
                audio_url = records[0]["audioUrl"]
                with urllib.request.urlopen(audio_url, timeout=60) as resp:
                    return resp.read()

            time.sleep(5)

        raise TimeoutError("Suno generation timed out")

    @property
    def cost_per_track(self) -> float:
        return 0.004  # ~$10/month for 2500 credits
