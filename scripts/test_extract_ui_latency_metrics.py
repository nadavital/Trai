#!/usr/bin/env python3
"""Lightweight validation for extract_ui_latency_metrics helpers."""

from __future__ import annotations

import pathlib
import sys
import unittest

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from extract_ui_latency_metrics import collect_test_ids, scan_activities_for_metrics  # noqa: E402


class ExtractLatencyMetricTests(unittest.TestCase):
    def test_collect_test_ids_traverses_nested_nodes(self) -> None:
        payload = [
            {
                "nodeType": "Test Plan",
                "children": [
                    {
                        "nodeType": "Test Case",
                        "nodeIdentifierURL": "test://A",
                    },
                    {
                        "nodeType": "Test Suite",
                        "children": [
                            {
                                "nodeType": "Test Case",
                                "nodeIdentifier": "test://B",
                            }
                        ],
                    },
                ],
            }
        ]

        ids = collect_test_ids(payload)
        self.assertEqual(set(ids), {"test://A", "test://B"})

    def test_scan_activities_for_metrics_extracts_values(self) -> None:
        activities = [
            {"title": "something else"},
            {
                "title": "Latency metric startup_to_tabbar=4.821s",
                "childActivities": [
                    {"title": "Latency metric reopen_to_tabbar=1.102s"}
                ],
            },
        ]
        metrics: dict[str, float] = {}

        scan_activities_for_metrics(activities, metrics)

        self.assertEqual(metrics["startup_to_tabbar"], 4.821)
        self.assertEqual(metrics["reopen_to_tabbar"], 1.102)


if __name__ == "__main__":
    unittest.main()
