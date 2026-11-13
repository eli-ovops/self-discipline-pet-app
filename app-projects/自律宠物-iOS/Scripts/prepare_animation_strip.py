#!/usr/bin/env python3
"""Extract a chroma-keyed horizontal pet strip into aligned PNG frames.

This script is deterministic post-processing only. Character art is generated
outside this script and remains available under Docs/ArtProduction for review.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import deque
from pathlib import Path

from PIL import Image


def parse_hex_color(value: str) -> tuple[int, int, int]:
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise argparse.ArgumentTypeError("chroma key must use #RRGGBB")
    return tuple(int(value[index : index + 2], 16) for index in (1, 3, 5))


def remove_chroma(
    image: Image.Image,
    key: tuple[int, int, int],
    threshold: float,
) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, _ = pixels[x, y]
            distance = math.sqrt(
                (red - key[0]) ** 2
                + (green - key[1]) ** 2
                + (blue - key[2]) ** 2
            )
            if distance <= threshold:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def connected_components(image: Image.Image) -> list[tuple[int, int, int, int, int]]:
    alpha = image.getchannel("A")
    width, height = image.size
    data = alpha.tobytes()
    visited = bytearray(width * height)
    components: list[tuple[int, int, int, int, int]] = []

    for start, alpha_value in enumerate(data):
        if alpha_value <= 16 or visited[start]:
            continue
        queue = deque([start])
        visited[start] = 1
        min_x = width
        min_y = height
        max_x = 0
        max_y = 0
        area = 0
        while queue:
            current = queue.pop()
            area += 1
            x = current % width
            y = current // width
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
            for neighbor in (
                current - 1 if x > 0 else -1,
                current + 1 if x + 1 < width else -1,
                current - width if y > 0 else -1,
                current + width if y + 1 < height else -1,
            ):
                if neighbor >= 0 and not visited[neighbor] and data[neighbor] > 16:
                    visited[neighbor] = 1
                    queue.append(neighbor)
        components.append((min_x, min_y, max_x + 1, max_y + 1, area))
    return components


def frame_boxes(image: Image.Image, count: int) -> list[tuple[int, int, int, int]]:
    components = connected_components(image)
    meaningful = [item for item in components if item[4] >= 1_000]
    if len(meaningful) != count:
        raise SystemExit(
            f"expected {count} complete sprite components, found {len(meaningful)}"
        )
    meaningful.sort(key=lambda item: (item[0] + item[2]) / 2)
    return [(left, top, right, bottom) for left, top, right, bottom, _ in meaningful]


def aligned_frames(
    image: Image.Image,
    boxes: list[tuple[int, int, int, int]],
    canvas_size: int,
    padding: int,
) -> list[Image.Image]:
    maximum_width = max(right - left for left, _, right, _ in boxes)
    maximum_height = max(bottom - top for _, top, _, bottom in boxes)
    scale = min(
        (canvas_size - padding * 2) / maximum_width,
        (canvas_size - padding * 2) / maximum_height,
    )

    frames: list[Image.Image] = []
    for left, top, right, bottom in boxes:
        sprite = image.crop((left, top, right, bottom))
        target_width = max(1, round(sprite.width * scale))
        target_height = max(1, round(sprite.height * scale))
        sprite = sprite.resize((target_width, target_height), Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        x = (canvas_size - target_width) // 2
        y = canvas_size - padding - target_height
        frame.alpha_composite(sprite, (x, y))
        frames.append(frame)
    return frames


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--frames", type=int, default=4)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--chroma-key", type=parse_hex_color, default="#FF00FF")
    parser.add_argument("--threshold", type=float, default=72.0)
    parser.add_argument("--canvas-size", type=int, default=640)
    parser.add_argument("--padding", type=int, default=24)
    args = parser.parse_args()

    source = Path(args.input).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(source) as opened:
        transparent = remove_chroma(opened, args.chroma_key, args.threshold)
    boxes = frame_boxes(transparent, args.frames)
    frames = aligned_frames(transparent, boxes, args.canvas_size, args.padding)

    outputs: list[str] = []
    for index, frame in enumerate(frames):
        output = output_dir / f"{args.prefix}-{index + 1:02d}.png"
        frame.save(output)
        outputs.append(str(output))

    manifest = {
        "source": str(source),
        "frameCount": len(outputs),
        "canvasSize": args.canvas_size,
        "chromaKey": "#%02X%02X%02X" % args.chroma_key,
        "threshold": args.threshold,
        "outputs": outputs,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
