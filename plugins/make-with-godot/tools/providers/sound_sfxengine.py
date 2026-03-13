"""SFX Engine 효과음 Provider (기본, 무료)"""

import json
import urllib.request
import urllib.error
from . import SoundProvider


class SFXEngineSoundProvider(SoundProvider):

    def __init__(self):
        self.base_url = "https://sfxengine.com/api/v1"

    def generate_sfx(self, prompt: str, duration: float = 1.0) -> bytes:
        payload = {
            "prompt": prompt,
            "duration": min(duration, 5.0)  # 최대 5초
        }

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base_url}/generate",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                result = json.loads(resp.read().decode("utf-8"))

            # 결과에서 오디오 URL/데이터 추출
            audio_url = result.get("audio_url") or result.get("url")
            if audio_url:
                with urllib.request.urlopen(audio_url, timeout=30) as resp:
                    return resp.read()

            # base64 데이터인 경우
            import base64
            audio_data = result.get("audio_data") or result.get("data")
            if audio_data:
                return base64.b64decode(audio_data)

            raise RuntimeError("No audio in SFX Engine response")

        except urllib.error.HTTPError as e:
            raise RuntimeError(f"SFX Engine API error: {e.code} {e.reason}")

    @property
    def cost_per_sound(self) -> float:
        return 0.0  # 무료
