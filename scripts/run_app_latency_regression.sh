#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/run_app_latency_regression.sh [options]

Options:
  --sim-id <udid>               Simulator UDID (preferred when known)
  --sim-destination <dest>      Full xcodebuild destination string
  --baseline <path>             Baseline budget JSON path
  --output-json <path>          Output JSON summary path
  --report <path>               Output markdown report path
  -h, --help                    Show this help

Examples:
  ./scripts/run_app_latency_regression.sh
  ./scripts/run_app_latency_regression.sh --sim-id 9A193875-8572-4D4A-A51B-477D0E73C84D
  ./scripts/run_app_latency_regression.sh --sim-destination 'platform=iOS Simulator,id=<UDID>'
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command '$1'" >&2
    exit 1
  fi
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Trai.xcodeproj"
EXTRACT_SCRIPT="$ROOT_DIR/scripts/extract_ui_latency_metrics.py"
BASELINE_PATH="$ROOT_DIR/scripts/latency_baseline_simulator.json"
REPORT_PATH="$ROOT_DIR/.agent/done/app-latency-regression-report.md"

SIM_ID=""
SIM_DESTINATION=""
OUTPUT_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim-id)
      SIM_ID="$2"
      shift 2
      ;;
    --sim-destination)
      SIM_DESTINATION="$2"
      shift 2
      ;;
    --baseline)
      BASELINE_PATH="$2"
      shift 2
      ;;
    --output-json)
      OUTPUT_JSON="$2"
      shift 2
      ;;
    --report)
      REPORT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd xcodebuild
require_cmd xcrun
require_cmd python3
require_cmd tee

if [[ ! -f "$PROJECT_PATH/project.pbxproj" ]]; then
  echo "error: could not find Xcode project at $PROJECT_PATH" >&2
  exit 1
fi

if [[ ! -f "$EXTRACT_SCRIPT" ]]; then
  echo "error: missing extractor script at $EXTRACT_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$BASELINE_PATH" ]]; then
  echo "error: baseline file not found: $BASELINE_PATH" >&2
  exit 1
fi

resolve_sim_destination() {
  if [[ -n "$SIM_DESTINATION" ]]; then
    printf "%s\n" "$SIM_DESTINATION"
    return
  fi

  if [[ -n "$SIM_ID" ]]; then
    printf "platform=iOS Simulator,id=%s\n" "$SIM_ID"
    return
  fi

  local destination
  destination="$(python3 <<'PY'
import json
import subprocess
import sys

preferred_names = [
    "iPhone 17",
    "iPhone 17 Pro",
    "iPhone 17 Pro Max",
    "iPhone Air",
    "iPhone 16",
]

try:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        text=True,
    )
except subprocess.CalledProcessError:
    sys.exit(1)

data = json.loads(raw)
devices = data.get("devices", {})

def runtime_score(runtime_key: str):
    suffix = runtime_key.rsplit(".", 1)[-1]
    parts = suffix.split("-")
    if len(parts) < 3 or parts[0] != "iOS":
        return (0, 0, 0)
    try:
        major = int(parts[1])
        minor = int(parts[2])
    except ValueError:
        return (0, 0, 0)
    patch = int(parts[3]) if len(parts) > 3 and parts[3].isdigit() else 0
    return (major, minor, patch)

for runtime in sorted(devices.keys(), key=runtime_score, reverse=True):
    available = [d for d in devices.get(runtime, []) if d.get("isAvailable")]
    iphones = [d for d in available if "iPhone" in d.get("name", "")]
    if not iphones:
        continue

    for preferred in preferred_names:
        for device in iphones:
            if device.get("name") == preferred:
                print(f"platform=iOS Simulator,id={device['udid']}")
                raise SystemExit(0)

    print(f"platform=iOS Simulator,id={iphones[0]['udid']}")
    raise SystemExit(0)

raise SystemExit(1)
PY
  )" || true

  if [[ -z "$destination" ]]; then
    echo "error: unable to auto-select an available simulator destination" >&2
    exit 1
  fi

  printf "%s\n" "$destination"
}

DESTINATION="$(resolve_sim_destination)"
TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
RESULT_BUNDLE="/tmp/trai-app-latency-${TIMESTAMP_UTC}.xcresult"
XCODEBUILD_LOG="/tmp/trai-app-latency-${TIMESTAMP_UTC}.log"
METRICS_JSON="/tmp/trai-app-latency-metrics-${TIMESTAMP_UTC}.json"
if [[ -n "$OUTPUT_JSON" ]]; then
  SUMMARY_JSON="$OUTPUT_JSON"
else
  SUMMARY_JSON="/tmp/trai-app-latency-summary-${TIMESTAMP_UTC}.json"
fi

echo "==> Running app latency smoke UI tests"
echo "==> Destination: $DESTINATION"
echo "==> Result bundle: $RESULT_BUNDLE"

set +e
xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "TraiTests" \
  -destination "$DESTINATION" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:TraiUITests/TraiUITests/testStartupAndTabSwitchLatencySmoke \
  -only-testing:TraiUITests/TraiUITests/testForegroundReopenLatencySmoke \
  -only-testing:TraiUITests/TraiUITests/testTabSwitchContentReadyLatencySmoke \
  -only-testing:TraiUITests/TraiUITests/testLiveWorkoutAddExerciseSheetLatencySmoke \
  | tee "$XCODEBUILD_LOG"
XCODEBUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "error: xcodebuild did not produce a result bundle at $RESULT_BUNDLE" >&2
  exit 1
fi

python3 "$EXTRACT_SCRIPT" --xcresult "$RESULT_BUNDLE" --pretty --out "$METRICS_JSON" >/dev/null

mkdir -p "$(dirname "$REPORT_PATH")"
mkdir -p "$(dirname "$SUMMARY_JSON")"

python3 - "$BASELINE_PATH" "$METRICS_JSON" "$SUMMARY_JSON" "$REPORT_PATH" "$TIMESTAMP_UTC" "$DESTINATION" "$RESULT_BUNDLE" "$XCODEBUILD_STATUS" <<'PY'
import json
import pathlib
import sys

baseline_path = pathlib.Path(sys.argv[1])
metrics_path = pathlib.Path(sys.argv[2])
summary_path = pathlib.Path(sys.argv[3])
report_path = pathlib.Path(sys.argv[4])
timestamp_utc = sys.argv[5]
destination = sys.argv[6]
result_bundle = sys.argv[7]
xcodebuild_status = int(sys.argv[8])

baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
metrics_payload = json.loads(metrics_path.read_text(encoding="utf-8"))
observed = metrics_payload.get("metrics", {})
budgets = baseline.get("budgets_seconds", {})

if not isinstance(observed, dict):
    raise SystemExit("error: malformed metrics payload")
if not isinstance(budgets, dict):
    raise SystemExit("error: malformed baseline payload")

ordered_metric_names = sorted(budgets.keys())
results = {}
missing_metrics = []
failed_metrics = []

for metric_name in ordered_metric_names:
    budget_raw = budgets[metric_name]
    try:
        budget = float(budget_raw)
    except (TypeError, ValueError):
        raise SystemExit(f"error: invalid budget for {metric_name}: {budget_raw}")

    value_raw = observed.get(metric_name)
    if value_raw is None:
        result = {"status": "MISSING", "budget_seconds": budget}
        results[metric_name] = result
        missing_metrics.append(metric_name)
        print(f"[latency] {metric_name}=missing (budget {budget:.3f}s) FAIL")
        continue

    value = float(value_raw)
    status = "PASS" if value <= budget else "FAIL"
    result = {
        "status": status,
        "value_seconds": value,
        "budget_seconds": budget,
        "delta_seconds": value - budget,
    }
    results[metric_name] = result
    print(f"[latency] {metric_name}={value:.3f}s (budget {budget:.3f}s) {status}")
    if status == "FAIL":
        failed_metrics.append(metric_name)

overall_pass = (
    xcodebuild_status == 0
    and not missing_metrics
    and not failed_metrics
)
overall_status = "PASS" if overall_pass else "FAIL"
print(f"[latency] xcodebuild_status={xcodebuild_status}")
print(f"[latency] overall result: {overall_status}")

summary = {
    "timestamp_utc": timestamp_utc,
    "destination": destination,
    "result_bundle": result_bundle,
    "xcodebuild_status": xcodebuild_status,
    "overall_status": overall_status,
    "baseline_file": str(baseline_path),
    "metrics_file": str(metrics_path),
    "metrics": observed,
    "budgets_seconds": budgets,
    "results": results,
    "missing_metrics": missing_metrics,
    "failed_metrics": failed_metrics,
    "tests_scanned": metrics_payload.get("tests_scanned", 0),
    "extractor_errors": metrics_payload.get("errors", []),
}
summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

report_lines = [
    "# App Latency Regression Report",
    "",
    f"- Timestamp (UTC): {timestamp_utc}",
    f"- Destination: `{destination}`",
    f"- Result bundle: `{result_bundle}`",
    f"- Baseline file: `{baseline_path}`",
    f"- Metrics file: `{metrics_path}`",
    f"- xcodebuild status: `{xcodebuild_status}`",
    f"- Overall status: **{overall_status}**",
    "",
    "## Metrics",
    "",
    "| Metric | Value (s) | Budget (s) | Status |",
    "| --- | ---: | ---: | --- |",
]

for metric_name in ordered_metric_names:
    result = results[metric_name]
    value = result.get("value_seconds")
    value_text = f"{value:.3f}" if isinstance(value, (int, float)) else "missing"
    budget = result.get("budget_seconds", 0.0)
    report_lines.append(
        f"| `{metric_name}` | {value_text} | {float(budget):.3f} | {result['status']} |"
    )

if summary["extractor_errors"]:
    report_lines.extend(
        [
            "",
            "## Extractor Errors",
            "",
        ]
    )
    for error in summary["extractor_errors"]:
        report_lines.append(f"- `{error}`")

report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
PY

echo "[latency] summary json: $SUMMARY_JSON"
echo "[latency] markdown report: $REPORT_PATH"
echo "[latency] xcodebuild log: $XCODEBUILD_LOG"

OVERALL_STATUS="$(python3 - "$SUMMARY_JSON" <<'PY'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(payload.get("overall_status", "FAIL"))
PY
)"

if [[ "$OVERALL_STATUS" != "PASS" ]]; then
  exit 1
fi
