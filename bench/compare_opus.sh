#!/usr/bin/env bash
SUDX_SET="$(realpath "$1")"
SUDX_OUT="$(realpath -m "$2")"
source "$(dirname "$0")/env.sh"
set -e
mkdir -p "$SUDX_OUT/rtl_work"
cd "$SUDX_OUT/rtl_work"
xrun -64bit -sv -q -timescale 1ns/1ps \
  +incdir+"$MY_K5_PROJ/bench/opus" \
  "$MY_K5_PROJ/bench/opus/sud_geom_pkg.sv" \
  "$MY_K5_PROJ/bench/opus/alwaysud_solver.sv" \
  "$MY_K5_PROJ/bench/opus/adapter.sv" \
  "$MY_K5_PROJ/bench/tb_solver.sv" \
  +PUZZLES="$SUDX_SET" +OUT="$SUDX_OUT/cycles.txt"
