"""Configuration loaded from environment."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import find_dotenv, load_dotenv

# find_dotenv() walks up from CWD until it finds .env — works whether the
# skill lives in the project tree, ~/.claude/skills, or anywhere else.
_ENV_PATH = find_dotenv(usecwd=True)
if _ENV_PATH:
    ROOT = Path(_ENV_PATH).resolve().parent
    load_dotenv(_ENV_PATH, override=False)
else:
    ROOT = Path(__file__).resolve().parents[4]  # best-effort fallback


@dataclass(frozen=True)
class Config:
    liner_api_key: str | None
    liner_base_url: str
    anthropic_api_key: str | None
    anthropic_base_url: str | None
    anthropic_model: str
    output_dir: Path
    max_wonder_rounds: int
    max_refine_rounds: int

    @classmethod
    def load(cls) -> "Config":
        return cls(
            # Accept both naming conventions seen in the wild.
            liner_api_key=os.getenv("LINER_API_KEY") or os.getenv("LINER_APIKEY"),
            liner_base_url=os.getenv("LINER_BASE_URL", "https://platform.liner.com"),
            anthropic_api_key=os.getenv("ANTHROPIC_API_KEY")
            or os.getenv("ANTHROPIC_AUTH_TOKEN"),
            anthropic_base_url=os.getenv("ANTHROPIC_BASE_URL"),
            anthropic_model=os.getenv(
                "ANTHROPIC_MODEL",
                os.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL", "claude-sonnet-4-6"),
            ),
            output_dir=Path(os.getenv("RESEARCH_OUTPUT_DIR", ROOT / "research_output")),
            max_wonder_rounds=int(os.getenv("MAX_WONDER_ROUNDS", "5")),
            max_refine_rounds=int(os.getenv("MAX_REFINE_ROUNDS", "3")),
        )


CONFIG = Config.load()