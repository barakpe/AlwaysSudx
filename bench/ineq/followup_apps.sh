#!/usr/bin/env bash
# One course simulation connection: validate the release rejections first,
# then run the optional extra-stage experiment's solvable application suite.
set -e
cd "$(dirname "$0")/../.."
bash bench/ineq/sim.sh ineq/dev/p6_contradiction logs/ineq-v3/app-rejects unsolved
bash bench/ineq/sim.sh ineq/dev/p7_impossible logs/ineq-v3/app-rejects unsolved
bash bench/ineq/all_apps.sh logs/experiment-mrv-decide/app logs/experiment-mrv-decide/rtl_work
