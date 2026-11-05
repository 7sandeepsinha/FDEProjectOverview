"""Load settings from config/settings.toml. Environment variables override the file."""
 
import os
import tomllib
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
 
from dotenv import load_dotenv
 
from meridian_workbench.reconcile import DUPLICATE_POLICIES
 
PROJECT_ROOT = Path(__file__).resolve().parents[2]
SETTINGS_FILE = PROJECT_ROOT / "config" / "settings.toml"
AI_MODES = ("recorded", "live")
 
 
@dataclass(frozen=True)
class Settings:
    data_dir: Path
    output_dir: Path
    fixtures_dir: Path
    golden_dir: Path
    batch_date: date
    ai_mode: str
    model: str
    prompt_version: str
    max_tokens: int
    timeout_seconds: float
    duplicate_policy: str
    max_quarantine_share: float
    retry_max_attempts: int
    retry_base_seconds: float
    retry_cap_seconds: float
    # repr=False keeps the key out of print(settings) and out of error messages
    api_key: str | None = field(default=None, repr=False)
 
    @property
    def cache_path(self) -> Path:
        return self.output_dir / "suggestion_cache.json"
 
 
def _path_from(override: str | None, configured: str) -> Path:
    """MERIDIAN_DATA_DIR, when set, points the run at another folder of the same four files."""
    return Path(override) if override else PROJECT_ROOT / configured
 
 
def load_settings() -> Settings:
    load_dotenv(PROJECT_ROOT / ".env")
 
    with open(SETTINGS_FILE, "rb") as f:
        raw = tomllib.load(f)
 
    batch_date_text = os.environ.get("MERIDIAN_BATCH_DATE", raw["rules"]["batch_date"])
    ai_mode = os.environ.get("MERIDIAN_AI_MODE", raw["ai"]["mode"])
    if ai_mode not in AI_MODES:
        raise ValueError(f"MERIDIAN_AI_MODE must be one of {AI_MODES}, not '{ai_mode}'")
    duplicate_policy = raw["intake"]["duplicate_policy"]
    if duplicate_policy not in DUPLICATE_POLICIES:
        raise ValueError(f"[intake] duplicate_policy must be one of {DUPLICATE_POLICIES}")
 
    return Settings(
        data_dir=_path_from(os.environ.get("MERIDIAN_DATA_DIR"), raw["paths"]["data_dir"]),
        output_dir=PROJECT_ROOT / raw["paths"]["output_dir"],
        fixtures_dir=PROJECT_ROOT / raw["paths"]["fixtures_dir"],
        golden_dir=PROJECT_ROOT / raw["paths"]["golden_dir"],
        batch_date=date.fromisoformat(batch_date_text),
        ai_mode=ai_mode,
        model=os.environ.get("MERIDIAN_LLM_MODEL", raw["ai"]["model"]),
        prompt_version=raw["ai"]["prompt_version"],
        max_tokens=int(raw["ai"]["max_tokens"]),
        timeout_seconds=float(raw["ai"]["timeout_seconds"]),
        duplicate_policy=duplicate_policy,
        max_quarantine_share=float(raw["intake"]["max_quarantine_share"]),
        retry_max_attempts=int(raw["retry"]["max_attempts"]),
        retry_base_seconds=float(raw["retry"]["base_seconds"]),
        retry_cap_seconds=float(raw["retry"]["cap_seconds"]),
        api_key=os.environ.get("MERIDIAN_LLM_API_KEY") or None,
    )
