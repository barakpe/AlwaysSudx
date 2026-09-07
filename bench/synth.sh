#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
set -e
cd "$MY_K5_XLRS/sudx_scan"
qsyn_xlr sudx_scan -all

