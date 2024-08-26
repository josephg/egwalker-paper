#!/usr/bin/env bash
set -e
set -o xtrace

# Build benchmarking tools

# DT (egwalker)
cargo build --release -p bench --manifest-path tools/diamond-types/Cargo.toml

# DT-CRDT (reference CRDT)
cargo build --release -p run_on_old --features bench --manifest-path tools/diamond-types/Cargo.toml

# OT
cargo build --release --features bench --manifest-path tools/ot-bench/Cargo.toml

# Yrs + AM
cargo build --release --features bench --manifest-path tools/paper-benchmarks/Cargo.toml

# Yjs
(
  cd tools/bench-yjs && node bench-remote.js
)

# DT (egwalker)
echo "DT"
sleep 5
taskset 0x1 nice -10 tools/diamond-types/target/release/bench --bench merge_norm/

echo "DT with FF optimisations turned off"
sleep 5
taskset 0x1 nice -10 tools/diamond-types/target/release/bench --bench ff_off/

echo "DT file load time"
sleep 5
taskset 0x1 nice -10 tools/diamond-types/target/release/bench --bench opt_load/


# DT-CRDT
echo "DT-CRDT"
sleep 5
taskset 0x1 nice -10 tools/diamond-types/target/release/run_on_old --bench process_remote_edits/

# Yrs
echo "YRS"
sleep 5
taskset 0x1 nice -10 tools/paper-benchmarks/target/release/paper-benchmarks --bench yrs/remote/

# Automerge
echo "Automerge"
sleep 5
taskset 0x1 nice -10 tools/paper-benchmarks/target/release/paper-benchmarks --bench automerge/remote/

# OT - this one takes 10 hours
echo "OT - Sleeping for 5 seconds to cool down CPU..."
sleep 5
taskset 0x1 nice -10 tools/ot-bench/target/release/ot-bench --bench
