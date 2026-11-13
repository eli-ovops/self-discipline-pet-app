#!/usr/bin/env python3
"""Install reviewed Beta 0.2 pet frames into the Xcode asset catalog."""

from __future__ import annotations

import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "DisciplinedPet/Resources/Assets.xcassets"
PRODUCTION = ROOT / "Docs/ArtProduction/Beta-v0.2/AnimationRuns"


def install(species: str, source_prefix: str, action: str, index: int) -> None:
    asset_name = f"{species}{action.title()}{index:02d}"
    filename = f"{source_prefix}-{action}-{index:02d}.png"
    source = PRODUCTION / f"{species}ActionSet/frames" / filename
    destination = CATALOG / f"{asset_name}.imageset"
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination / filename)
    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (destination / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    for species, prefix in (("Milo", "milo"), ("Max", "max")):
        for action in ("tap", "focus", "celebrate"):
            for index in range(1, 5):
                install(species, prefix, action, index)


if __name__ == "__main__":
    main()
