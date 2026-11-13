#!/usr/bin/env python3
"""Turn a 4-column by 3-row chroma action sheet into aligned PNG frames.

The expected row order is tap, focus, celebrate.  This is deterministic local
post-processing: generated source sheets remain under Docs/ArtProduction for
visual review and provenance.
"""

from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

from PIL import Image


ACTION_NAMES = ("tap", "focus", "celebrate")


def remove_magenta(image: Image.Image) -> Image.Image:
    """Remove a vivid magenta background and softly feather contaminated edges."""
    rgba = image.convert("RGBA")
    output: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in rgba.getdata():
        magenta = min(red, blue) - green
        balance = abs(red - blue)
        is_magenta_family = max(red, blue) >= 135 and balance <= 105

        if is_magenta_family and magenta >= 78:
            output.append((0, 0, 0, 0))
        elif is_magenta_family and magenta >= 42:
            feather = 1 - (magenta - 42) / 36
            output.append((red, green, blue, round(alpha * max(0, feather))))
        else:
            output.append((red, green, blue, alpha))
    rgba.putdata(output)
    return rgba


def proportional_bounds(length: int, count: int) -> list[int]:
    return [round(index * length / count) for index in range(count + 1)]


def visible_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > 16 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise SystemExit("a grid cell contains no visible sprite")
    return bbox


def keep_largest_component(image: Image.Image) -> Image.Image:
    """Discard neighboring-cell fragments while keeping the complete pet pose."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    width, height = rgba.size
    values = alpha.tobytes()
    visited = bytearray(width * height)
    components: list[list[int]] = []

    for start, alpha_value in enumerate(values):
        if alpha_value <= 16 or visited[start]:
            continue
        queue = deque([start])
        visited[start] = 1
        component: list[int] = []
        while queue:
            current = queue.pop()
            component.append(current)
            x = current % width
            y = current // width
            for neighbor in (
                current - 1 if x > 0 else -1,
                current + 1 if x + 1 < width else -1,
                current - width if y > 0 else -1,
                current + width if y + 1 < height else -1,
            ):
                if neighbor >= 0 and not visited[neighbor] and values[neighbor] > 16:
                    visited[neighbor] = 1
                    queue.append(neighbor)
        components.append(component)

    if not components:
        raise SystemExit("a grid cell contains no connected sprite")
    keep = set(max(components, key=len))
    pixels = list(rgba.getdata())
    rgba.putdata(
        [pixel if index in keep else (0, 0, 0, 0) for index, pixel in enumerate(pixels)]
    )
    return rgba


def extract_rows(image: Image.Image) -> list[list[Image.Image]]:
    x_bounds = proportional_bounds(image.width, 4)
    y_bounds = proportional_bounds(image.height, 3)
    rows: list[list[Image.Image]] = []
    for row in range(3):
        cells: list[Image.Image] = []
        for column in range(4):
            cell = image.crop(
                (
                    x_bounds[column],
                    y_bounds[row],
                    x_bounds[column + 1],
                    y_bounds[row + 1],
                )
            )
            cell = keep_largest_component(cell)
            cells.append(cell.crop(visible_bbox(cell)))
        rows.append(cells)
    return rows


def align_row(
    sprites: list[Image.Image],
    *,
    canvas_size: int,
    padding: int,
) -> list[Image.Image]:
    maximum_width = max(sprite.width for sprite in sprites)
    maximum_height = max(sprite.height for sprite in sprites)
    scale = min(
        (canvas_size - padding * 2) / maximum_width,
        (canvas_size - padding * 2) / maximum_height,
    )

    frames: list[Image.Image] = []
    for sprite in sprites:
        target_width = max(1, round(sprite.width * scale))
        target_height = max(1, round(sprite.height * scale))
        resized = sprite.resize(
            (target_width, target_height), Image.Resampling.LANCZOS
        )
        frame = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        x = (canvas_size - target_width) // 2
        y = canvas_size - padding - target_height
        frame.alpha_composite(resized, (x, y))
        frames.append(frame)
    return frames


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--canvas-size", type=int, default=640)
    parser.add_argument("--padding", type=int, default=24)
    args = parser.parse_args()

    source = Path(args.input).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(source) as opened:
        transparent = remove_magenta(opened)
    rows = extract_rows(transparent)

    outputs: dict[str, list[str]] = {}
    for action, row in zip(ACTION_NAMES, rows):
        frames = align_row(
            row,
            canvas_size=args.canvas_size,
            padding=args.padding,
        )
        action_outputs: list[str] = []
        for index, frame in enumerate(frames, start=1):
            output = output_dir / f"{args.prefix}-{action}-{index:02d}.png"
            frame.save(output)
            action_outputs.append(str(output))
        outputs[action] = action_outputs

    manifest = {
        "source": str(source),
        "grid": {"columns": 4, "rows": 3},
        "rowOrder": list(ACTION_NAMES),
        "framesPerAction": 4,
        "canvasSize": args.canvas_size,
        "backgroundRemoval": "magenta-family feather v1",
        "outputs": outputs,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
