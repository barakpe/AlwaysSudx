#!/usr/bin/env bash
# Source the installed course environment, then select this isolated K5 tree.
SUDX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shopt -s expand_aliases
source ~/.bashrc >/dev/null 2>&1
source /apps/common/bin/startProject.bash tsmc65 >/dev/null 2>&1
export MY_K5_PROJ="$SUDX_ROOT"
export MY_K5_XLRS="$MY_K5_PROJ/hw/xlrs"
export K5_SW_APPS="$MY_K5_PROJ/sw/apps"

