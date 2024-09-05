#!/usr/bin/env bash
set -e
set -o xtrace

rm -f results/*
rm -rf target/criterion
cargo clean --manifest-path tools/diamond-types/Cargo.toml
cargo clean --manifest-path tools/crdt-converter/Cargo.toml
cargo clean --manifest-path tools/ot-bench/Cargo.toml
cargo clean --manifest-path tools/paper-benchmarks/Cargo.toml
