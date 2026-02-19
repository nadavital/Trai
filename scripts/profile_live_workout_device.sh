#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  ./scripts/profile_live_workout_device.sh --udid <DEVICE_UDID> --bundle-id <BUNDLE_ID> [options]

Required:
  --udid <id>            Physical iPhone/iPad UDID
  --bundle-id <id>       App bundle identifier (e.g. Nadav.Trai)

Options:
  --duration <seconds>   Capture duration in seconds (default: 90)
  --tag <name>           Output tag for artifact names (default: run)
  --output-dir <path>    Artifact directory (default: /tmp)
  --skip-launch          Do not relaunch app before profiling
  --launch-arg <arg>     Extra launch argument (repeatable)

Artifacts:
  <output-dir>/Trai-liveworkout-<tag>-<timestamp>.trace
  <output-dir>/Trai-liveworkout-<tag>-time-sample.xml
  <output-dir>/Trai-liveworkout-<tag>-hotspots.csv
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command '$1'" >&2
    exit 1
  fi
}

UDID=""
BUNDLE_ID=""
DURATION="90"
TAG="run"
OUTPUT_DIR="/tmp"
SKIP_LAUNCH="0"
LAUNCH_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid)
      UDID="$2"
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
    --tag)
      TAG="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --skip-launch)
      SKIP_LAUNCH="1"
      shift 1
      ;;
    --launch-arg)
      LAUNCH_ARGS+=("$2")
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

if [[ -z "$UDID" || -z "$BUNDLE_ID" ]]; then
  echo "error: --udid and --bundle-id are required" >&2
  usage
  exit 1
fi

if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || [[ "$DURATION" -le 0 ]]; then
  echo "error: --duration must be a positive integer" >&2
  exit 1
fi

require_cmd xcrun
require_cmd python3

mkdir -p "$OUTPUT_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TRACE_PATH="$OUTPUT_DIR/Trai-liveworkout-${TAG}-${TIMESTAMP}.trace"
TOC_PATH="$OUTPUT_DIR/Trai-liveworkout-${TAG}-${TIMESTAMP}-toc.xml"
XML_PATH="$OUTPUT_DIR/Trai-liveworkout-${TAG}-time-sample.xml"
HOTSPOTS_PATH="$OUTPUT_DIR/Trai-liveworkout-${TAG}-hotspots.csv"
PROCESS_JSON="$OUTPUT_DIR/Trai-liveworkout-${TAG}-${TIMESTAMP}-processes.json"

if [[ "$SKIP_LAUNCH" == "1" ]]; then
  echo "Resolving process ID for $BUNDLE_ID..."
  xcrun devicectl device info processes \
    --device "$UDID" \
    --json-output "$PROCESS_JSON" >/dev/null

  APP_NAME="${BUNDLE_ID##*.}"

  PID="$({
python3 - "$PROCESS_JSON" "$BUNDLE_ID" "$APP_NAME" <<'PY'
import json
import sys

path = sys.argv[1]
bundle = sys.argv[2]
app_name = sys.argv[3]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

matches = []

def walk(node):
    if isinstance(node, dict):
        bundle_id = node.get("bundleIdentifier") or node.get("bundleID")
        executable = node.get("executable")
        pid = node.get("processIdentifier") or node.get("pid")
        executable_matches = (
            isinstance(executable, str)
            and f"/{app_name}.app/" in executable
        )
        if isinstance(pid, int) and (bundle_id == bundle or executable_matches):
            matches.append(pid)
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)

walk(data)
if matches:
    print(max(matches))
PY
} || true)"

  if [[ -z "$PID" ]]; then
    echo "error: unable to find running process for bundle '$BUNDLE_ID'" >&2
    echo "hint: manually open the app on the device and rerun with --skip-launch" >&2
    exit 1
  fi

  echo "Attaching Time Profiler to pid $PID for ${DURATION}s..."
  xcrun xctrace record \
    --template 'Time Profiler' \
    --time-limit "${DURATION}s" \
    --output "$TRACE_PATH" \
    --device "$UDID" \
    --attach "$PID" \
    --no-prompt >/dev/null
else
  echo "Launching and profiling $BUNDLE_ID on device $UDID for ${DURATION}s..."
  record_cmd=(
    xcrun xctrace record
    --template 'Time Profiler'
    --time-limit "${DURATION}s"
    --output "$TRACE_PATH"
    --device "$UDID"
    --no-prompt
    --launch --
    "$BUNDLE_ID"
  )
  if [[ ${#LAUNCH_ARGS[@]} -gt 0 ]]; then
    record_cmd+=("${LAUNCH_ARGS[@]}")
  fi
  "${record_cmd[@]}" >/dev/null
fi

echo "Exporting trace table-of-contents..."
if xcrun xctrace export --input "$TRACE_PATH" --toc --output "$TOC_PATH" >/dev/null; then
  XPATH="$({
python3 - "$TOC_PATH" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
run = root.find("run")
if run is None:
    raise SystemExit("")

data = run.find("data")
if data is None:
    raise SystemExit("")

schemas = [table.attrib.get("schema", "") for table in data.findall("table")]
index = None
for preferred in ("time-profile", "time-sample"):
    for i, schema in enumerate(schemas, start=1):
        if schema == preferred:
            index = i
            break
    if index is not None:
        break

if index is not None:
    print(f"/trace-toc/run[@number='1']/data/table[{index}]")
PY
} || true)"

  if [[ -z "$XPATH" ]]; then
    echo "warning: failed to resolve export xpath from trace TOC; skipping XML/hotspots export." >&2
  elif xcrun xctrace export --input "$TRACE_PATH" --xpath "$XPATH" --output "$XML_PATH" >/dev/null; then
    echo "Summarizing hotspots..."
    python3 - "$XML_PATH" "$HOTSPOTS_PATH" <<'PY'
import csv
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter

xml_path = sys.argv[1]
csv_path = sys.argv[2]

root = ET.parse(xml_path).getroot()

thread_fmt_by_id = {}
bt_fmt_by_id = {}

for elem in root.iter():
    elem_id = elem.attrib.get("id")
    fmt = elem.attrib.get("fmt")
    if not elem_id or not fmt:
        continue
    if elem.tag == "thread":
        thread_fmt_by_id[elem_id] = fmt
    elif elem.tag == "kperf-bt":
        bt_fmt_by_id[elem_id] = fmt

counter = Counter()

for row in root.iter("row"):
    thread = row.find("thread")
    if thread is None:
        continue

    thread_fmt = thread.attrib.get("fmt")
    if thread_fmt is None and "ref" in thread.attrib:
        thread_fmt = thread_fmt_by_id.get(thread.attrib["ref"], "(unknown thread)")

    # Prefer symbol-rich "time-profile" format: backtrace -> first frame name.
    bt_head = None
    backtrace = row.find("backtrace")
    if backtrace is not None:
        frame = backtrace.find("frame")
        if frame is not None:
            bt_head = frame.attrib.get("name")

    # Fallback to "time-sample" format.
    if not bt_head:
        bt = row.find("kperf-bt")
        if bt is not None:
            bt_fmt = bt.attrib.get("fmt")
            if bt_fmt is None and "ref" in bt.attrib:
                bt_fmt = bt_fmt_by_id.get(bt.attrib["ref"], "(unknown callstack)")
            if bt_fmt:
                match = re.search(r"PC:([^,]+)", bt_fmt)
                bt_head = match.group(1).strip() if match else bt_fmt

    if not bt_head:
        continue

    counter[(thread_fmt or "(unknown thread)", bt_head)] += 1

with open(csv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["rank", "samples", "thread", "pc_or_callstack_head"])
    for rank, ((thread, pc), samples) in enumerate(counter.most_common(40), start=1):
        writer.writerow([rank, samples, thread, pc])
PY
  else
    echo "warning: xctrace XML export failed; keeping raw .trace artifact only." >&2
  fi
else
  echo "warning: xctrace TOC export failed; keeping raw .trace artifact only." >&2
fi

echo "Done."
echo "trace:    $TRACE_PATH"
if [[ -f "$XML_PATH" ]]; then
  echo "samples:  $XML_PATH"
fi
if [[ -f "$HOTSPOTS_PATH" ]]; then
  echo "hotspots: $HOTSPOTS_PATH"
fi
