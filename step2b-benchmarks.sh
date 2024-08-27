#!/usr/bin/env bash
set -e
set -o xtrace

# Build benchmarking tools

# This is strictly unnecessary. This pins the benchmark process to a single core and gives it
# maximum priority. This has the effect of reducing run-to-run benchmarking variance by about 5% or
# so on my CPU.
CONDITION="taskset 0x1 nice -10"

# DT (egwalker)
cargo build --release -p bench --manifest-path tools/diamond-types/Cargo.toml

# DT-CRDT (reference CRDT)
cargo build --release -p run_on_old --features bench --manifest-path tools/diamond-types/Cargo.toml

# OT
cargo build --release --features bench --manifest-path tools/ot-bench/Cargo.toml

# Yrs + AM
cargo build --release --features bench --manifest-path tools/paper-benchmarks/Cargo.toml

# DT (egwalker)
echo "DT"
$CONDITION tools/diamond-types/target/release/bench --bench merge_norm/

echo "DT with FF optimisations turned off"
$CONDITION tools/diamond-types/target/release/bench --bench ff_off/

echo "DT file load time"
$CONDITION tools/diamond-types/target/release/bench --bench opt_load/


# DT-CRDT
echo "DT-CRDT"
$CONDITION tools/diamond-types/target/release/run_on_old --bench process_remote_edits/

# Yrs
echo "YRS"
$CONDITION tools/paper-benchmarks/target/release/paper-benchmarks --bench yrs/remote/

# Automerge
echo "Automerge"
$CONDITION tools/paper-benchmarks/target/release/paper-benchmarks --bench automerge/remote/

# OT - this one takes 10 hours
echo "OT - Sleeping for 5 seconds to cool down CPU..."
$CONDITION tools/ot-bench/target/release/ot-bench --bench

# Yjs
(
  cd tools/bench-yjs && node bench-remote.js
)
