#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/run_live_workout_stability.sh [options]

Modes:
  --mode sim|device|all      Run simulator checks, device profiling, or both (default: sim)

Simulator options:
  --sim-destination <dest>   xcodebuild destination (default: auto-select available iPhone simulator)
  --with-app-latency         Also run full app latency regression script in simulator mode

Device options:
  --device-udid <id>         Physical device UDID (required for --mode device|all)
  --bundle-id <id>           App bundle identifier (default: Nadav.Trai)
  --duration <seconds>       Per-capture duration (default: 90)
  --output-dir <path>        Profile artifact directory (default: /tmp)
  --tag-prefix <name>        Artifact tag prefix (default: stability)

Examples:
  ./scripts/run_live_workout_stability.sh
  ./scripts/run_live_workout_stability.sh --mode device --device-udid <UDID>
  ./scripts/run_live_workout_stability.sh --mode all --device-udid <UDID> --duration 120
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command '$1'" >&2
    exit 1
  fi
}

MODE="sim"
SIM_DESTINATION=""
WITH_APP_LATENCY="0"
DEVICE_UDID=""
BUNDLE_ID="Nadav.Trai"
DURATION="90"
OUTPUT_DIR="/tmp"
TAG_PREFIX="stability"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --sim-destination)
      SIM_DESTINATION="$2"
      shift 2
      ;;
    --with-app-latency)
      WITH_APP_LATENCY="1"
      shift
      ;;
    --device-udid)
      DEVICE_UDID="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --duration)
      DURATION="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --tag-prefix)
      TAG_PREFIX="$2"
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

case "$MODE" in
  sim|device|all) ;;
  *)
    echo "error: --mode must be one of: sim, device, all" >&2
    exit 1
    ;;
esac

if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || [[ "$DURATION" -le 0 ]]; then
  echo "error: --duration must be a positive integer" >&2
  exit 1
fi

if [[ "$MODE" == "device" || "$MODE" == "all" ]]; then
  if [[ -z "$DEVICE_UDID" ]]; then
    echo "error: --device-udid is required for --mode $MODE" >&2
    exit 1
  fi
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Trai.xcodeproj"
PROFILE_SCRIPT="$ROOT_DIR/scripts/profile_live_workout_device.sh"

require_cmd xcodebuild
require_cmd xcrun
require_cmd bash
require_cmd python3

resolve_sim_destination() {
  if [[ -n "$SIM_DESTINATION" ]]; then
    printf "%s\n" "$SIM_DESTINATION"
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
    "iPhone 16e",
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
    # Runtime keys look like: com.apple.CoreSimulator.SimRuntime.iOS-26-2
    suffix = runtime_key.rsplit(".", 1)[-1]
    if "-" not in suffix:
        return (0, 0, 0)
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

ranked_runtimes = sorted(devices.keys(), key=runtime_score, reverse=True)

for runtime in ranked_runtimes:
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
    echo "error: unable to auto-select an available iPhone simulator; pass --sim-destination explicitly." >&2
    exit 1
  fi

  printf "%s\n" "$destination"
}

run_simulator_checks() {
  local sim_destination
  sim_destination="$(resolve_sim_destination)"
  echo "==> Using simulator destination: $sim_destination"

  echo "==> Running targeted live-workout unit tests on simulator"
  xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "TraiTests" \
    -destination "$sim_destination" \
    -only-testing:TraiTests/ActiveWorkoutRuntimeStateTests \
    -only-testing:TraiTests/LiveWorkoutPersistenceCoordinatorTests \
    -only-testing:TraiTests/LiveWorkoutUpdatePolicyTests \
    -only-testing:TraiTests/LiveWorkoutPerformanceGuardrailsTests

  echo "==> Running live-workout UI stability flow on simulator"
  RUN_LIVE_WORKOUT_STABILITY_UI_STRESS=1 xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "TraiTests" \
    -destination "$sim_destination" \
    -only-testing:TraiUITests/TraiUITests/testLiveWorkoutStabilityPresetHandlesRepeatedMutationsAndReopen

  echo "==> Running startup and navigation latency smoke UI checks on simulator"
  xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "TraiTests" \
    -destination "$sim_destination" \
    -only-testing:TraiUITests/TraiUITests/testStartupAndTabSwitchLatencySmoke \
    -only-testing:TraiUITests/TraiUITests/testLiveWorkoutAddExerciseSheetLatencySmoke

  if [[ "$WITH_APP_LATENCY" == "1" ]]; then
    echo "==> Running full app latency regression guardrail on simulator"
    "$ROOT_DIR/scripts/run_app_latency_regression.sh" --sim-destination "$sim_destination"
  fi
}

run_device_profile() {
  if [[ ! -x "$PROFILE_SCRIPT" ]]; then
    echo "error: expected executable profile script at $PROFILE_SCRIPT" >&2
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"

  echo "==> Recording fresh-state device trace"
  bash "$PROFILE_SCRIPT" \
    --udid "$DEVICE_UDID" \
    --bundle-id "$BUNDLE_ID" \
    --duration "$DURATION" \
    --output-dir "$OUTPUT_DIR" \
    --tag "${TAG_PREFIX}-fresh" \
    --launch-arg "-pendingAppRoute" \
    --launch-arg "trai://workout"

  echo "==> Recording heavy-data device trace"
  bash "$PROFILE_SCRIPT" \
    --udid "$DEVICE_UDID" \
    --bundle-id "$BUNDLE_ID" \
    --duration "$DURATION" \
    --output-dir "$OUTPUT_DIR" \
    --tag "${TAG_PREFIX}-heavy" \
    --launch-arg "--seed-live-workout-perf-data" \
    --launch-arg "-pendingAppRoute" \
    --launch-arg "trai://workout"
}

if [[ "$MODE" == "sim" || "$MODE" == "all" ]]; then
  run_simulator_checks
fi

if [[ "$MODE" == "device" || "$MODE" == "all" ]]; then
  run_device_profile
fi

echo "Live workout stability run complete."
