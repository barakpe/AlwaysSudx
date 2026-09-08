#!/usr/bin/env bash
SUDX_SET="$(realpath "$1")"
SUDX_OUT="$(realpath -m "$2")"
SUDX_SOLVER="${3:-}"
SUDX_EXPECT_FAIL="${4:-0}"
if [ -n "$SUDX_SOLVER" ]; then SUDX_SOLVER="$(realpath "$SUDX_SOLVER")"; fi
source "$(dirname "$0")/../env.sh"
set -e
SUDX_SOLVER="${SUDX_SOLVER:-$MY_K5_XLRS/ineqsudx_scan/ineqsudx_scan_solver.sv}"
mkdir -p "$SUDX_OUT/rtl_work"
cd "$SUDX_OUT/rtl_work"
xrun -64bit -sv -q -timescale 1ns/1ps \
  "$SUDX_SOLVER" \
  "$MY_K5_PROJ/bench/ineq/tb_solver.sv" \
  +PUZZLES="$SUDX_SET" +OUT="$SUDX_OUT/cycles.txt" +EXPECT_FAIL="$SUDX_EXPECT_FAIL"
