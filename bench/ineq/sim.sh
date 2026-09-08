#!/usr/bin/env bash
SUDX_BOARD="$1"
SUDX_EXPECT="${3:-solved}"
SUDX_ALT_XLRS="${4:-}"
if [ -n "$SUDX_ALT_XLRS" ]; then SUDX_ALT_XLRS="$(realpath "$SUDX_ALT_XLRS")"; fi
SUDX_LABEL="${SUDX_BOARD//\//_}"
SUDX_OUT="$(realpath -m "$2")"
source "$(dirname "$0")/../env.sh"
set -e
if [ -n "$SUDX_ALT_XLRS" ]; then export MY_K5_XLRS="$SUDX_ALT_XLRS"; fi
mkdir -p "$SUDX_OUT"
sha256sum "$MY_K5_XLRS/ineqsudx_scan/"*.sv > "$SUDX_OUT/$SUDX_LABEL.sources.sha256"
cd "$MY_K5_PROJ/sim"
launch_k5_sim ineqsudx_scan > "$SUDX_OUT/$SUDX_LABEL.sim.log" 2>&1 &
SUDX_SIM_PID=$!
launch_k5_app ineqsudx_scan -asl sud_shared -gpv "$SUDX_BOARD" > "$SUDX_OUT/$SUDX_LABEL.app.log" 2>&1
wait "$SUDX_SIM_PID"
grep -E 'Sudoku solve|checker|App reported' "$SUDX_OUT/$SUDX_LABEL.app.log"
! grep -q 'FAILED\|FAIL:' "$SUDX_OUT/$SUDX_LABEL.app.log"
if [ "$SUDX_EXPECT" = unsolved ]; then
    grep -q 'App reported non-solved.' "$SUDX_OUT/$SUDX_LABEL.app.log"
    ! grep -q 'Solved board PASSED' "$SUDX_OUT/$SUDX_LABEL.app.log"
else
    grep -q 'Solved board PASSED basic Sudoku checker' "$SUDX_OUT/$SUDX_LABEL.app.log"
    grep -q 'Solved board PASSED inequalities checker' "$SUDX_OUT/$SUDX_LABEL.app.log"
fi
