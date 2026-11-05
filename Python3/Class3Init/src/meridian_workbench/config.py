"""Load settings from config/settings.toml. Environment variables override the file."""
 
import os
import tomllib
from datetime import date
from pathlib import Path
 
from dotenv import load_dotenv
 
PROJECT_ROOT = Path(__file__).resolve().parents[2]
SETTINGS_FILE = PROJECT_ROOT / "config" / "settings.toml"
 
 
def load_settings():
    """Return the settings as a dictionary."""
    load_dotenv(PROJECT_ROOT / ".env")
 
    with open(SETTINGS_FILE, "rb") as f:
        raw = tomllib.load(f)
 
    batch_date_text = os.environ.get("MERIDIAN_BATCH_DATE", raw["rules"]["batch_date"])
    ai_mode = os.environ.get("MERIDIAN_AI_MODE", raw["ai"]["mode"])
 
    return {
        "data_dir": PROJECT_ROOT / raw["paths"]["data_dir"],
        "output_dir": PROJECT_ROOT / raw["paths"]["output_dir"],
        "fixtures_dir": PROJECT_ROOT / raw["paths"]["fixtures_dir"],
        "batch_date": date.fromisoformat(batch_date_text),
        "ai_mode": ai_mode,
    }
