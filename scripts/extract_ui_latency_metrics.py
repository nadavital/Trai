#!/usr/bin/env python3
"""Extract latency metrics logged by Trai UI tests from an .xcresult bundle."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

METRIC_PATTERN = re.compile(r"Latency metric ([A-Za-z0-9_]+)=([0-9]+(?:\.[0-9]+)?)s")


def run_json_command(command: list[str]) -> dict[str, Any]:
    output = subprocess.check_output(command, text=True)
    return json.loads(output)


def collect_test_ids(test_nodes: list[dict[str, Any]]) -> list[str]:
    stack: list[dict[str, Any]] = list(test_nodes)
    seen: set[str] = set()
    test_ids: list[str] = []

    while stack:
        node = stack.pop()
        node_type = node.get("nodeType")
        if node_type == "Test Case":
            test_id = node.get("nodeIdentifierURL") or node.get("nodeIdentifier")
            if isinstance(test_id, str) and test_id and test_id not in seen:
                seen.add(test_id)
                test_ids.append(test_id)

        children = node.get("children")
        if isinstance(children, list):
            for child in children:
                if isinstance(child, dict):
                    stack.append(child)

    return test_ids


def scan_activities_for_metrics(activities: list[dict[str, Any]], metrics: dict[str, float]) -> None:
    stack: list[dict[str, Any]] = list(activities)

    while stack:
        activity = stack.pop()
        title = activity.get("title")
        if isinstance(title, str):
            match = METRIC_PATTERN.search(title)
            if match:
                metric_name = match.group(1)
                metrics[metric_name] = float(match.group(2))

        child_activities = activity.get("childActivities")
        if isinstance(child_activities, list):
            for child in child_activities:
                if isinstance(child, dict):
                    stack.append(child)


def extract_metrics(xcresult_path: Path) -> dict[str, Any]:
    tests_payload = run_json_command(
        [
            "xcrun",
            "xcresulttool",
            "get",
            "test-results",
            "tests",
            "--path",
            str(xcresult_path),
            "--compact",
        ]
    )

    test_nodes = tests_payload.get("testNodes")
    if not isinstance(test_nodes, list):
        raise RuntimeError("Unable to parse test nodes from xcresult.")

    test_ids = collect_test_ids(test_nodes)
    metrics: dict[str, float] = {}
    extraction_errors: list[dict[str, str]] = []

    for test_id in test_ids:
        try:
            activities_payload = run_json_command(
                [
                    "xcrun",
                    "xcresulttool",
                    "get",
                    "test-results",
                    "activities",
                    "--path",
                    str(xcresult_path),
                    "--test-id",
                    test_id,
                    "--compact",
                ]
            )
        except subprocess.CalledProcessError as exc:
            extraction_errors.append(
                {
                    "test_id": test_id,
                    "error": f"xcresulttool activities failed with exit code {exc.returncode}",
                }
            )
            continue

        test_runs = activities_payload.get("testRuns")
        if not isinstance(test_runs, list):
            continue

        for run in test_runs:
            if not isinstance(run, dict):
                continue
            activities = run.get("activities")
            if isinstance(activities, list):
                scan_activities_for_metrics(activities, metrics)

    return {
        "xcresult_path": str(xcresult_path),
        "tests_scanned": len(test_ids),
        "metric_count": len(metrics),
        "metrics": dict(sorted(metrics.items())),
        "errors": extraction_errors,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract 'Latency metric ...' values from an .xcresult bundle."
    )
    parser.add_argument(
        "--xcresult",
        required=True,
        help="Path to an .xcresult bundle produced by xcodebuild test.",
    )
    parser.add_argument(
        "--out",
        help="Optional output JSON file path. If omitted, JSON is only printed to stdout.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    xcresult_path = Path(args.xcresult).expanduser()

    if not xcresult_path.exists():
        print(f"error: xcresult path does not exist: {xcresult_path}", file=sys.stderr)
        return 1

    try:
        payload = extract_metrics(xcresult_path)
    except subprocess.CalledProcessError as exc:
        print(
            f"error: failed running xcresulttool (exit {exc.returncode}) for {xcresult_path}",
            file=sys.stderr,
        )
        return 1
    except (json.JSONDecodeError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    json_text = json.dumps(payload, indent=2 if args.pretty else None, sort_keys=True)

    if args.out:
        output_path = Path(args.out).expanduser()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json_text + "\n", encoding="utf-8")

    print(json_text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
