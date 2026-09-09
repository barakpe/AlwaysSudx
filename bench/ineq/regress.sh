#!/usr/bin/env bash
# Run independent RTL checks sequentially, keeping complete tool logs per set.
set -e
INEQ_SOLVER="$(realpath "$1")"
INEQ_OUT="$(realpath -m "$2")"
shift 2
if [ "$#" -eq 0 ]; then set -- official classic generated heldout rejects contract; fi
mkdir -p "$INEQ_OUT"
for INEQ_GROUP in "$@"; do
    bash "$(dirname "$0")/rtl.sh" "$(dirname "$0")/puzzles/$INEQ_GROUP.txt" \
        "$INEQ_OUT/$INEQ_GROUP" "$INEQ_SOLVER" > "$INEQ_OUT/$INEQ_GROUP.log" 2>&1
    grep 'REGRESSION PASS' "$INEQ_OUT/$INEQ_GROUP.log"
done
