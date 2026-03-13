"""Flux 2 Pro 이미지 생성 Provider (fal.ai 경유)"""

import os
import json
import time
import urllib.request
import urllib.error
from . import ImageProvider


class FluxImageProvider(ImageProvider):

    def __init__(self):
        self.api_key = os.environ.get("FAL_API_KEY")
        if not self.api_key:
            raise ValueError("FAL_API_KEY environment variable required")
        self.base_url = "https://queue.fal.run/fal-ai/flux-pro/v1.1"

    def generate(self, prompt: str, size: str = "1024x1024",
                 aspect: str = "1:1") -> bytes:
        # fal.ai queue API
        headers = {
            "Authorization": f"Key {self.api_key}",
            "Content-Type": "application/json"
        }

        # 크기 파싱
        parts = size.split("x") if "x" in size else []
        w, h = (parts[0], parts[1]) if len(parts) >= 2 else ("1024", "1024")

        payload = {
            "prompt": prompt,
            "image_size": {"width": int(w), "height": int(h)},
            "num_images": 1,
            "safety_tolerance": "2"
        }

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self.base_url,
            data=data,
            headers=headers,
            method="POST"
        )

        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                result = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"Flux API error {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}") from e

        # queue 방식이면 request_id로 폴링
        if "request_id" in result:
            return self._poll_result(result["request_id"], headers)

        # 직접 응답이면 이미지 URL에서 다운로드
        return self._download_image(result)

    def _poll_result(self, request_id: str, headers: dict) -> bytes:
        status_url = f"https://queue.fal.run/fal-ai/flux-pro/v1.1/requests/{request_id}/status"
        result_url = f"https://queue.fal.run/fal-ai/flux-pro/v1.1/requests/{request_id}"

        for _ in range(60):
            req = urllib.request.Request(status_url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as resp:
                status = json.loads(resp.read().decode("utf-8"))
            if status.get("status") == "COMPLETED":
                req = urllib.request.Request(result_url, headers=headers)
                with urllib.request.urlopen(req, timeout=30) as resp:
                    result = json.loads(resp.read().decode("utf-8"))
                return self._download_image(result)
            time.sleep(2)

        raise TimeoutError("Flux generation timed out")

    def _download_image(self, result: dict) -> bytes:
        images = result.get("images", [])
        if not images:
            raise RuntimeError("No images in Flux response")
        url = images[0].get("url")
        if not url:
            raise RuntimeError("No image URL in Flux response")
        with urllib.request.urlopen(url, timeout=60) as resp:
            return resp.read()

    @property
    def cost_per_image(self) -> float:
        return 0.055
