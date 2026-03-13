"""Meshy 이미지→GLB Provider (대안)"""

import os
import json
import time
import urllib.request
import urllib.error
import base64
from pathlib import Path
from . import Model3DProvider


class MeshyModel3DProvider(Model3DProvider):

    def __init__(self):
        self.api_key = os.environ.get("MESHY_API_KEY")
        if not self.api_key:
            raise ValueError("MESHY_API_KEY environment variable required")
        self.base_url = "https://api.meshy.ai/v2"

    def image_to_glb(self, image: Path, quality: str = "medium") -> bytes:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        # 이미지를 base64로 인코딩
        with open(image, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode("utf-8")

        payload = {
            "image_url": f"data:image/png;base64,{img_b64}",
            "ai_model": "meshy-4",
            "topology": "quad",
            "target_polycount": 30000 if quality == "high" else 10000
        }

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base_url}/image-to-3d",
            data=data,
            headers=headers,
            method="POST"
        )

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"Meshy API error {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}") from e

        task_id = result.get("result")
        if not task_id:
            raise RuntimeError(f"No task ID in Meshy response: {result}")

        # 폴링
        for _ in range(120):
            req = urllib.request.Request(
                f"{self.base_url}/image-to-3d/{task_id}",
                headers=headers
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                status = json.loads(resp.read().decode("utf-8"))

            if status["status"] == "SUCCEEDED":
                model_url = status["model_urls"]["glb"]
                with urllib.request.urlopen(model_url, timeout=60) as resp:
                    return resp.read()
            elif status["status"] == "FAILED":
                raise RuntimeError(f"Meshy task failed: {status.get('task_error', {}).get('message', 'unknown')}")

            time.sleep(3)

        raise TimeoutError("Meshy generation timed out")

    @property
    def cost_per_model(self) -> float:
        return 0.20
