#!/usr/bin/env bash
# Run the official application serially: K5 uses one per-user simulator socket.
set -euo pipefail
cd "$(dirname "$0")/../../.."
for version in v3 v4; do
    if [ "$version" = v3 ]; then
        repo=AlwaysSudxIneqBuild
    else
        repo=AlwaysSudxIneqV4
    fi
    for board in std/hard5 std/hard8 ineq/set0/single ineq/set0/ascend ineq/set0/plain ineq/set1/sparse_ineq ineq/set2/superhardA ineq/set2/xsparse2; do
        echo "$version $board"
        bash "$repo/bench/ineq/sim.sh" "$board" "$repo/logs/ineq-$version/benchmark-app"
    done
done
