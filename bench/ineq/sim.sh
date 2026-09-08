#!/usr/bin/env bash
SUDX_BOARD="$1"
SUDX_LABEL="${SUDX_BOARD//\//_}"
SUDX_OUT="$(realpath -m "$2")"
source "$(dirname "$0")/../env.sh"
set -e
mkdir -p "$SUDX_OUT"
cd "$MY_K5_PROJ/sim"
launch_k5_sim ineqsudx_scan > "$SUDX_OUT/$SUDX_LABEL.sim.log" 2>&1 &
SUDX_SIM_PID=$!
launch_k5_app ineqsudx_scan -asl sud_shared -gpv "$SUDX_BOARD" > "$SUDX_OUT/$SUDX_LABEL.app.log" 2>&1
wait "$SUDX_SIM_PID"
grep -E 'Sudoku solve|checker|App reported' "$SUDX_OUT/$SUDX_LABEL.app.log"
! grep -q 'FAILED\|FAIL:' "$SUDX_OUT/$SUDX_LABEL.app.log"
grep -q 'Solved board PASSED basic Sudoku checker' "$SUDX_OUT/$SUDX_LABEL.app.log"
grep -q 'Solved board PASSED inequalities checker' "$SUDX_OUT/$SUDX_LABEL.app.log"
