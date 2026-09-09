#!/usr/bin/env bash
SUDX_BOARD="$1"
SUDX_OUT="$(realpath -m "$2")"
# Board names may contain a set directory, e.g. std/hard1; flatten for filenames.
SUDX_LABEL="${SUDX_BOARD//\//_}"
source "$(dirname "$0")/env.sh"
set -e
mkdir -p "$SUDX_OUT"
cd "$MY_K5_PROJ/sim"
launch_k5_sim sudx_scan > "$SUDX_OUT/$SUDX_LABEL.sim.log" 2>&1 &
SUDX_SIM_PID=$!
launch_k5_app sudx_scan -asl sud_shared -gpv "$SUDX_BOARD" > "$SUDX_OUT/$SUDX_LABEL.app.log" 2>&1
wait "$SUDX_SIM_PID"
grep -E 'Sudoku solve|final checker' "$SUDX_OUT/$SUDX_LABEL.app.log"
grep -q 'Solved board PASSED final checker' "$SUDX_OUT/$SUDX_LABEL.app.log"

