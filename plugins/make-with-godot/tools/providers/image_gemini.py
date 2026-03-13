"""Gemini 이미지 생성 Provider (기본)"""

import os
import base64
import json
import urllib.request
import urllib.error
from . import ImageProvider


class GeminiImageProvider(ImageProvider):

    def __init__(self):
        self.api_key = os.environ.get("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY environment variable required")
        self.model = "gemini-2.0-flash-exp"
        self.base_url = "https://generativelanguage.googleapis.com/v1beta"

    def generate(self, prompt: str, size: str = "1024x1024",
                 aspect: str = "1:1") -> bytes:
        url = f"{self.base_url}/models/{self.model}:generateContent"

        payload = {
            "contents": [{
                "parts": [{"text": f"Generate an image: {prompt}. Size: {size}. Aspect ratio: {aspect}."}]
            }],
            "generationConfig": {
                "responseModalities": ["TEXT", "IMAGE"]
            }
        }

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": self.api_key,
            },
            method="POST"
        )

        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                result = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"Gemini API error {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}") from e

        # 응답에서 이미지 추출
        for candidate in result.get("candidates", []):
            for part in candidate.get("content", {}).get("parts", []):
                if "inlineData" in part:
                    img_data = part["inlineData"]["data"]
                    return base64.b64decode(img_data)

        raise RuntimeError("No image in Gemini response")

    @property
    def cost_per_image(self) -> float:
        return 0.035
