#!/usr/bin/env bash
# The course uses a per-user simulation socket: run applications sequentially.
set -e
INEQ_OUT="$1"
INEQ_ALT_XLRS="${2:-}"
for INEQ_BOARD in 20blanks 51blanks easy1 hard1 \
    ineq/dev/p5_presolved \
    ineq/set0/ascend ineq/set0/plain ineq/set0/single ineq/set0/sparse1 \
    ineq/set1/easy1 ineq/set1/easy2 \
    ineq/set1/medium1 ineq/set1/medium2 ineq/set1/medium3 \
    ineq/set1/hard1 ineq/set1/hard2 ineq/set1/hard3 ineq/set1/hard4 \
    ineq/set1/sparse_ineq; do
    echo "Testing $INEQ_BOARD"
    bash "$(dirname "$0")/sim.sh" "$INEQ_BOARD" "$INEQ_OUT" solved "$INEQ_ALT_XLRS"
done
