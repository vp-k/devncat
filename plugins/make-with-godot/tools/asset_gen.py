#!/usr/bin/env python3
"""
asset_gen.py — 에셋 생성 오케스트레이터
이미지/3D/사운드/음악을 provider 추상화 레이어를 통해 생성합니다.
생성된 에셋은 progress JSON의 budget에 자동 기록됩니다.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# Provider 패키지 경로 추가
sys.path.insert(0, str(Path(__file__).parent))

from providers import (
    get_image_provider,
    get_model3d_provider,
    get_sound_provider,
    get_music_provider,
)

PROGRESS_FILE = ".claude-godot-progress.json"


def update_budget(asset_type: str, path: str, prompt: str,
                  provider_name: str, cost: float):
    """progress JSON의 에셋 예산 업데이트"""
    if not os.path.exists(PROGRESS_FILE):
        return

    with open(PROGRESS_FILE, "r") as f:
        progress = json.load(f)

    # 에셋 기록 추가
    ext = Path(path).suffix.lstrip(".")
    progress["assets"]["generated"].append({
        "type": ext,
        "path": path,
        "prompt": prompt[:200],  # 프롬프트 길이 제한
        "provider": provider_name,
        "cost": cost,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    })

    # 예산 카운터 업데이트
    budget = progress["assets"]["budget"]
    type_map = {
        "image": "images",
        "reference": "images",
        "model3d": "models",
        "sound": "sounds",
        "music": "music",
    }
    budget_key = type_map.get(asset_type, "images")
    budget[budget_key] = budget.get(budget_key, 0) + 1
    budget["totalCost"] = round(budget.get("totalCost", 0) + cost, 4)

    tmp_file = PROGRESS_FILE + ".tmp"
    with open(tmp_file, "w") as f:
        json.dump(progress, f, indent=2, ensure_ascii=False)
    os.replace(tmp_file, PROGRESS_FILE)


def generate_image(args):
    provider = get_image_provider()
    print(f"Generating image with {provider.__class__.__name__}...")
    data = provider.generate(
        prompt=args.prompt,
        size=args.size or "1024x1024",
        aspect=args.aspect or "1:1",
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)

    print(f"OK: {output} ({len(data)} bytes)")
    update_budget("image", str(output), args.prompt,
                  os.environ.get("IMAGE_PROVIDER", "gemini"),
                  provider.cost_per_image)


def generate_reference(args):
    """비주얼 타겟 참조 이미지 생성"""
    provider = get_image_provider()
    print(f"Generating reference image with {provider.__class__.__name__}...")
    data = provider.generate(
        prompt=args.prompt,
        size="1280x720",
        aspect="16:9",
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)

    print(f"OK: Reference image → {output} ({len(data)} bytes)")
    update_budget("reference", str(output), args.prompt,
                  os.environ.get("IMAGE_PROVIDER", "gemini"),
                  provider.cost_per_image)


def generate_model3d(args):
    if not args.input:
        print("ERROR: --input (reference image) required for 3D model generation")
        sys.exit(1)

    provider = get_model3d_provider()
    print(f"Generating 3D model with {provider.__class__.__name__}...")
    data = provider.image_to_glb(
        image=Path(args.input),
        quality=args.quality or "medium",
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)

    print(f"OK: {output} ({len(data)} bytes)")
    update_budget("model3d", str(output), f"from {args.input}",
                  os.environ.get("MODEL3D_PROVIDER", "tripo"),
                  provider.cost_per_model)


def generate_sound(args):
    provider = get_sound_provider()
    print(f"Generating SFX with {provider.__class__.__name__}...")
    data = provider.generate_sfx(
        prompt=args.prompt,
        duration=args.duration or 1.0,
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)

    print(f"OK: {output} ({len(data)} bytes)")
    update_budget("sound", str(output), args.prompt,
                  os.environ.get("SOUND_PROVIDER", "sfxengine"),
                  provider.cost_per_sound)


def generate_music(args):
    provider = get_music_provider()
    print(f"Generating BGM with {provider.__class__.__name__}...")
    data = provider.generate_bgm(
        prompt=args.prompt,
        duration=args.duration or 30,
        genre=args.genre or "",
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)

    print(f"OK: {output} ({len(data)} bytes)")
    update_budget("music", str(output), args.prompt,
                  os.environ.get("MUSIC_PROVIDER", "suno"),
                  provider.cost_per_track)


def main():
    parser = argparse.ArgumentParser(description="Make with Godot — Asset Generator")
    parser.add_argument("--type", required=True,
                        choices=["image", "reference", "model3d", "sound", "music"],
                        help="Asset type to generate")
    parser.add_argument("--prompt", default="",
                        help="Generation prompt")
    parser.add_argument("--output", required=True,
                        help="Output file path")
    parser.add_argument("--input", default=None,
                        help="Input file (for model3d: reference image)")
    parser.add_argument("--size", default=None,
                        help="Image size (e.g., 64x64, 1024x1024)")
    parser.add_argument("--aspect", default=None,
                        help="Aspect ratio (e.g., 1:1, 16:9)")
    parser.add_argument("--quality", default=None,
                        help="Quality level (for 3D: low/medium/high)")
    parser.add_argument("--duration", type=float, default=None,
                        help="Duration in seconds (for sound/music)")
    parser.add_argument("--genre", default=None,
                        help="Music genre (for music)")

    args = parser.parse_args()

    generators = {
        "image": generate_image,
        "reference": generate_reference,
        "model3d": generate_model3d,
        "sound": generate_sound,
        "music": generate_music,
    }

    try:
        generators[args.type](args)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
