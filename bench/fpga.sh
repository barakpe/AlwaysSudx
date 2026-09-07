#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
set -e
cd "$MY_K5_PROJ/hw/gen_fpga"
comp_fpga sudx_scan
test -s prog_files/k5_xbox_sudx_scan.sof
