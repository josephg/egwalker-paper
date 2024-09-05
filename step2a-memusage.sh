#!/usr/bin/env bash
set -e
set -o xtrace

# Yjs memory usage
(
  cd tools/bench-yjs
  npm i
  node --expose-gc bench-memusage.js
)

# Memory usage tool to measure Automerge & Yrs
cargo build --profile memusage --features memusage --manifest-path tools/paper-benchmarks/Cargo.toml

# Automerge memory usage
tools/paper-benchmarks/target/memusage/paper-benchmarks -a
# Yrs memory usage
tools/paper-benchmarks/target/memusage/paper-benchmarks -y

# dtcrdt (reference CRDT) memory usage
cargo build --profile memusage -p run_on_old --features memusage --manifest-path tools/diamond-types/Cargo.toml
tools/diamond-types/target/memusage/run_on_old

# dt (egwalker) memory usage & misc stats
cargo build --release -p paper-stats --features memusage --manifest-path tools/diamond-types/Cargo.toml
tools/diamond-types/target/release/paper-stats

# OT
echo 'NOTE: This takes 1+ hour to run!'
cargo build --profile memusage --features memusage --manifest-path tools/ot-bench/Cargo.toml
tools/ot-bench/target/memusage/ot-bench
