#!/usr/bin/env python3
"""
visual_qa.py — Gemini Flash 기반 Visual Question Answering
게임 스크린샷을 분석하여 시각적 품질을 평가합니다.
"""

import argparse
import base64
import glob
import json
import os
import sys
import urllib.request


def load_image_b64(path: str) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def run_vqa(screenshots: list, reference: str = None,
            questions: list = None) -> dict:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable required")

    model = "gemini-2.0-flash"
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

    if not questions:
        questions = [
            "Is the game rendering correctly?",
            "Are UI elements properly positioned?",
            "Do sprites appear intact (no clipping, no corruption)?",
            "Are layers in correct z-order?",
            "Does the visual style match the reference image?",
        ]

    # 프롬프트 구성
    parts = []
    parts.append({
        "text": (
            "You are a game QA visual inspector. Analyze these game screenshots "
            "and answer the following questions. "
            "For each issue found, classify severity as high/medium/low.\n\n"
            "Questions:\n" + "\n".join(f"- {q}" for q in questions) + "\n\n"
            "Respond in this exact JSON format:\n"
            '{"verdict": "pass|fail|acceptable", "score": 0.0-1.0, '
            '"issues": [{"severity": "high|medium|low", "description": "...", '
            '"suggestion": "..."}]}'
        )
    })

    # 참조 이미지
    if reference and os.path.exists(reference):
        parts.append({"text": "Reference image (target visual style):"})
        parts.append({
            "inlineData": {
                "mimeType": "image/png",
                "data": load_image_b64(reference)
            }
        })

    # 스크린샷
    for ss in screenshots:
        parts.append({"text": f"Screenshot: {os.path.basename(ss)}"})
        parts.append({
            "inlineData": {
                "mimeType": "image/png",
                "data": load_image_b64(ss)
            }
        })

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json"
        }
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read().decode("utf-8"))

    # 응답 텍스트 추출
    text = ""
    for candidate in result.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            if "text" in part:
                text += part["text"]

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {
            "verdict": "fail",
            "score": 0.0,
            "issues": [{"severity": "high",
                        "description": f"Failed to parse VQA response: {text[:200]}",
                        "suggestion": "Retry VQA"}],
            "raw_response": text[:500]
        }


def main():
    parser = argparse.ArgumentParser(description="Visual QA for game screenshots")
    parser.add_argument("--screenshots", required=True,
                        help="Screenshot glob pattern (e.g., 'screenshot_*.png')")
    parser.add_argument("--reference", default=None,
                        help="Reference image path")
    parser.add_argument("--questions", default=None,
                        help="Comma-separated questions")

    args = parser.parse_args()

    # glob 패턴으로 스크린샷 수집
    screenshots = sorted(glob.glob(args.screenshots))
    if not screenshots:
        print(json.dumps({
            "verdict": "fail",
            "score": 0.0,
            "issues": [{"severity": "high",
                        "description": f"No screenshots found matching: {args.screenshots}",
                        "suggestion": "Capture screenshots first"}]
        }, indent=2))
        sys.exit(1)

    questions = args.questions.split(",") if args.questions else None
    result = run_vqa(screenshots, args.reference, questions)

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
