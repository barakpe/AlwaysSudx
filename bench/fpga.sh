#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
set -e
cd "$MY_K5_PROJ/hw/gen_fpga"
# On RC the course utility deposits artifacts through the existing Desktop
# shortcut even when MY_K5_PROJ selects another tree. Collect only our new files.
SUDX_DROP="$(readlink -f /data/home/perezba/Desktop/k5_xbox_links/fpga_prog_files)"
for SUDX_EXT in sof svf; do
    if [ -e "$SUDX_DROP/k5_xbox_sudx_scan.$SUDX_EXT" ]; then
        echo "Refusing to overwrite an existing course artifact: $SUDX_DROP/k5_xbox_sudx_scan.$SUDX_EXT" >&2
        exit 1
    fi
done
comp_fpga sudx_scan
for SUDX_EXT in sof svf; do
    mv "$SUDX_DROP/k5_xbox_sudx_scan.$SUDX_EXT" "prog_files/k5_xbox_sudx_scan.$SUDX_EXT"
done
test -s prog_files/k5_xbox_sudx_scan.sof
grep -q 'Analysis & Synthesis was successful' output_files/map_k5_xbox_rc3.log
grep -q 'Fitter was successful' output_files/fit_k5_xbox_rc3.log
