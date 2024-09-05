#!/usr/bin/env bash
set -e
set -o xtrace

rm -f results/*
rm -rf target/criterion
cd tools/diamond-types && cargo clean
cd tools/crdt-converter && cargo clean
cd tools/ot-bench && cargo clean
cd tools/paper-benchmarks && cargo clean
