#!/usr/bin/env bash
# A private source snapshot permits a quick area experiment without changing
# the source files of a fitter already running on the current milestone.
SUDX_SOURCE="$(realpath "$1")"
SUDX_OUT="$(realpath -m "$2")"
SUDX_STAGE="${3:--all}"
source "$(dirname "$0")/env.sh"
set -e
mkdir -p "$SUDX_OUT/rtl_work/sudx_scan" "$SUDX_OUT/synthesis"
cp "$MY_K5_XLRS/sudx_scan/sudx_scan.sv" "$MY_K5_XLRS/sudx_scan/sudx_scan.f" \
   "$MY_K5_XLRS/sudx_scan/sudx_def_pkg.sv" "$SUDX_OUT/rtl_work/sudx_scan/"
cp "$SUDX_SOURCE" "$SUDX_OUT/rtl_work/sudx_scan/sudx_scan_solver.sv"
sha256sum "$SUDX_OUT/rtl_work/sudx_scan/"*.sv > "$SUDX_OUT/source.sha256"
export MY_K5_XLRS="$SUDX_OUT/rtl_work"
cd "$MY_K5_XLRS/sudx_scan"
qsyn_xlr sudx_scan "$SUDX_STAGE"
grep -q 'Analysis & Synthesis was successful' qsyn_output_files/map_sudx_scan.log
cp qsyn_output_files/*.rpt qsyn_output_files/*.summary "$SUDX_OUT/synthesis/"
