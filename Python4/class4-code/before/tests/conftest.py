"""Shared helpers: temporary settings and a private copy of the data."""
 
import shutil
from collections.abc import Callable
from dataclasses import replace
from pathlib import Path
from typing import Any
 
import pytest
 
from meridian_workbench.config import Settings, load_settings
 
 
@pytest.fixture
def settings_for(tmp_path: Path) -> Callable[..., Settings]:
    """Settings that write outputs under tmp_path, run in live mode, and carry a fake key."""
 
    def make(**changes: Any) -> Settings:
        base = replace(
            load_settings(),
            output_dir=tmp_path / "outputs",
            ai_mode="live",
            api_key="test-key-not-real",
        )
        return replace(base, **changes)
 
    return make
 
 
@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """A private copy of the real data files, so a test can never change the originals."""
    target = tmp_path / "data"
    shutil.copytree(load_settings().data_dir, target)
    return target
