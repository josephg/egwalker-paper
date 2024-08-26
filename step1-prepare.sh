#!/usr/bin/env bash
set -e
set -o xtrace

# cd tools/paper-benchmarks && cargo build --profile memusage --features memusage

cargo build --release --manifest-path tools/diamond-types/Cargo.toml -p dt-cli
cargo build --release --manifest-path tools/crdt-converter/Cargo.toml

DT=tools/diamond-types/target/release/dt
CRDTCONVERT=tools/crdt-converter/target/release/crdt-converter

$DT bench-duplicate datasets/raw/automerge-paper.dt -o datasets/S1.dt -n3 -f
$DT bench-duplicate datasets/raw/seph-blog1.dt -o datasets/S2.dt -n3 -f
$DT bench-duplicate datasets/raw/egwalker.dt -o datasets/S3.dt -n1 -f
$DT bench-duplicate datasets/raw/friendsforever.dt -o datasets/C1.dt -n25 -f
$DT bench-duplicate datasets/raw/clownschool.dt -o datasets/C2.dt -n25 -f
$DT bench-duplicate datasets/raw/node_nodecc.dt -o datasets/A1.dt -n1 -f
$DT bench-duplicate datasets/raw/git-makefile.dt -o datasets/A2.dt -n2 -f

$DT export-trace datasets/S1.dt -o datasets/S1.json
$DT export-trace datasets/S2.dt -o datasets/S2.json
$DT export-trace datasets/S3.dt -o datasets/S3.json
$DT export-trace datasets/C1.dt -o datasets/C1.json
$DT export-trace datasets/C2.dt -o datasets/C2.json
$DT export-trace datasets/A1.dt -o datasets/A1.json
$DT export-trace datasets/A2.dt -o datasets/A2.json

$CRDTCONVERT -y datasets/S1.json
$CRDTCONVERT -y datasets/S2.json
$CRDTCONVERT -y datasets/S3.json
$CRDTCONVERT -y datasets/C1.json
$CRDTCONVERT -y datasets/C2.json
$CRDTCONVERT -y datasets/A1.json
$CRDTCONVERT -y datasets/A2.json

$CRDTCONVERT -a datasets/S1.json
$CRDTCONVERT -a datasets/S2.json
$CRDTCONVERT -a datasets/S3.json
$CRDTCONVERT -a datasets/C1.json
$CRDTCONVERT -a datasets/C2.json
$CRDTCONVERT -a datasets/A1.json
$CRDTCONVERT -a datasets/A2.json
