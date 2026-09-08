#!/usr/bin/env bash
# Synthesize an isolated experimental solver using only the course utility.
INEQ_SOURCE="$(realpath "$1")"
INEQ_OUT="$(realpath -m "$2")"
INEQ_STAGE="${3:--all}"
source "$(dirname "$0")/../env.sh"
set -e
mkdir -p "$INEQ_OUT/rtl_work/ineqsudx_scan" "$INEQ_OUT/synthesis"
cp "$MY_K5_XLRS/ineqsudx_scan/ineqsudx_scan.sv" \
   "$MY_K5_XLRS/ineqsudx_scan/ineqsudx_scan.f" \
   "$MY_K5_XLRS/ineqsudx_scan/ineqsudx_def_pkg.sv" \
   "$INEQ_OUT/rtl_work/ineqsudx_scan/"
cp "$INEQ_SOURCE" "$INEQ_OUT/rtl_work/ineqsudx_scan/ineqsudx_scan_solver.sv"
sha256sum "$INEQ_OUT/rtl_work/ineqsudx_scan/"*.sv > "$INEQ_OUT/source.sha256"
export MY_K5_XLRS="$INEQ_OUT/rtl_work"
cd "$MY_K5_XLRS/ineqsudx_scan"
qsyn_xlr ineqsudx_scan "$INEQ_STAGE"
grep -q 'Analysis & Synthesis was successful' qsyn_output_files/map_ineqsudx_scan.log
if [ "$INEQ_STAGE" = -all ]; then
    grep -q 'Fitter was successful' qsyn_output_files/fit_ineqsudx_scan.log
    grep -q 'Timing Analyzer was successful' qsyn_output_files/sta_ineqsudx_scan.log
fi
cp qsyn_output_files/*.rpt qsyn_output_files/*.summary "$INEQ_OUT/synthesis/"
