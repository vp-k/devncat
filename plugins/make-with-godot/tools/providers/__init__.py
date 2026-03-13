"""
Make with Godot — Provider 추상화 레이어
모든 외부 AI API를 교체 가능하게 설계. 환경변수로 provider 선택.
"""

import os
from abc import ABC, abstractmethod
from pathlib import Path


class ImageProvider(ABC):
    """텍스트 → 이미지 (스프라이트, 배경, 3D 참조용)"""

    @abstractmethod
    def generate(self, prompt: str, size: str = "1024x1024",
                 aspect: str = "1:1") -> bytes:
        """프롬프트로 이미지 생성, PNG bytes 반환"""
        ...

    @property
    @abstractmethod
    def cost_per_image(self) -> float:
        """이미지 1장당 예상 비용 (USD)"""
        ...


class Model3DProvider(ABC):
    """이미지 → GLB 3D 모델"""

    @abstractmethod
    def image_to_glb(self, image: Path,
                     quality: str = "medium") -> bytes:
        """참조 이미지에서 GLB 모델 생성, bytes 반환"""
        ...

    @property
    @abstractmethod
    def cost_per_model(self) -> float:
        ...


class SoundProvider(ABC):
    """텍스트 → 효과음 (WAV/OGG)"""

    @abstractmethod
    def generate_sfx(self, prompt: str,
                     duration: float = 1.0) -> bytes:
        """효과음 생성, WAV bytes 반환"""
        ...

    @property
    @abstractmethod
    def cost_per_sound(self) -> float:
        ...


class MusicProvider(ABC):
    """텍스트 → BGM (OGG)"""

    @abstractmethod
    def generate_bgm(self, prompt: str,
                     duration: int = 30,
                     genre: str = "") -> bytes:
        """배경음악 생성, OGG bytes 반환"""
        ...

    @property
    @abstractmethod
    def cost_per_track(self) -> float:
        ...


def get_image_provider() -> ImageProvider:
    """환경변수 IMAGE_PROVIDER에 따라 provider 반환"""
    provider = os.environ.get("IMAGE_PROVIDER", "gemini").lower()
    if provider == "gemini":
        from .image_gemini import GeminiImageProvider
        return GeminiImageProvider()
    elif provider == "flux":
        from .image_flux import FluxImageProvider
        return FluxImageProvider()
    else:
        raise ValueError(f"Unknown image provider: {provider}")


def get_model3d_provider() -> Model3DProvider:
    provider = os.environ.get("MODEL3D_PROVIDER", "tripo").lower()
    if provider == "tripo":
        from .model3d_tripo import TripoModel3DProvider
        return TripoModel3DProvider()
    elif provider == "meshy":
        from .model3d_meshy import MeshyModel3DProvider
        return MeshyModel3DProvider()
    else:
        raise ValueError(f"Unknown 3D model provider: {provider}")


def get_sound_provider() -> SoundProvider:
    provider = os.environ.get("SOUND_PROVIDER", "sfxengine").lower()
    if provider == "sfxengine":
        from .sound_sfxengine import SFXEngineSoundProvider
        return SFXEngineSoundProvider()
    else:
        raise ValueError(f"Unknown sound provider: {provider}")


def get_music_provider() -> MusicProvider:
    provider = os.environ.get("MUSIC_PROVIDER", "suno").lower()
    if provider == "suno":
        from .music_suno import SunoMusicProvider
        return SunoMusicProvider()
    else:
        raise ValueError(f"Unknown music provider: {provider}")
