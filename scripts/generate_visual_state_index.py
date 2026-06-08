#!/usr/bin/env python3
"""Generate a local HTML contact sheet for Trai visual-state captures."""

from __future__ import annotations

import argparse
import html
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--ids", default="")
    parser.add_argument("--groups", default="")
    return parser.parse_args()


def selected_states(manifest: dict, ids: set[str], groups: set[str]) -> list[dict]:
    states = manifest.get("states", [])
    if ids:
        return [state for state in states if state.get("id") in ids]
    if groups:
        return [
            state
            for state in states
            if groups.intersection(set(state.get("groups", [])))
        ]
    return states


def main() -> None:
    args = parse_args()
    manifest_path = Path(args.manifest)
    output_dir = Path(args.output_dir)
    ids = {item for item in args.ids.split(",") if item}
    groups = {item for item in args.groups.split(",") if item}

    manifest = json.loads(manifest_path.read_text())
    states = selected_states(manifest, ids, groups)

    cards = []
    for state in states:
        state_id = state["id"]
        image_name = f"{state_id}.png"
        image_path = output_dir / image_name
        status = "captured" if image_path.exists() else "missing"
        title = html.escape(state.get("title", state_id))
        groups_text = ", ".join(state.get("groups", []))
        groups_html = html.escape(groups_text)
        if image_path.exists():
            image_html = f'<img src="{html.escape(image_name)}" alt="{title}">'
        else:
            image_html = '<div class="missing">Missing capture</div>'
        cards.append(
            f"""
            <article class="card {status}">
              <header>
                <h2>{title}</h2>
                <code>{html.escape(state_id)}</code>
              </header>
              {image_html}
              <p>{groups_html}</p>
            </article>
            """
        )

    page = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Trai Visual States</title>
  <style>
    :root {{
      color-scheme: light dark;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
      background: Canvas;
      color: CanvasText;
    }}
    body {{
      margin: 0;
      padding: 28px;
    }}
    h1 {{
      margin: 0 0 6px;
      font-size: 28px;
    }}
    .meta {{
      margin: 0 0 24px;
      color: color-mix(in srgb, CanvasText 64%, transparent);
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
      gap: 20px;
      align-items: start;
    }}
    .card {{
      border: 1px solid color-mix(in srgb, CanvasText 14%, transparent);
      border-radius: 10px;
      overflow: hidden;
      background: color-mix(in srgb, Canvas 92%, CanvasText 8%);
    }}
    .card header {{
      display: flex;
      justify-content: space-between;
      gap: 12px;
      align-items: baseline;
      padding: 12px 14px;
    }}
    .card h2 {{
      margin: 0;
      font-size: 16px;
    }}
    .card code {{
      font-size: 12px;
      color: color-mix(in srgb, CanvasText 58%, transparent);
    }}
    .card img {{
      display: block;
      width: 100%;
      background: #111;
    }}
    .card p {{
      margin: 0;
      padding: 10px 14px 14px;
      color: color-mix(in srgb, CanvasText 62%, transparent);
      font-size: 13px;
    }}
    .missing {{
      display: grid;
      min-height: 420px;
      place-items: center;
      color: color-mix(in srgb, CanvasText 55%, transparent);
    }}
  </style>
</head>
<body>
  <h1>Trai Visual States</h1>
  <p class="meta">{len(states)} states from {html.escape(str(manifest_path))}</p>
  <main class="grid">
    {''.join(cards)}
  </main>
</body>
</html>
"""
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "index.html").write_text(page)


if __name__ == "__main__":
    main()
