#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
set -e
cd "$MY_K5_XLRS/sudx_scan"
qsyn_xlr sudx_scan -all
# The course Python utility may return zero even after a Quartus failure.
grep -q 'Analysis & Synthesis was successful' qsyn_output_files/map_sudx_scan.log
grep -q 'Fitter was successful' qsyn_output_files/fit_sudx_scan.log
grep -q 'Timing Analyzer was successful' qsyn_output_files/sta_sudx_scan.log
