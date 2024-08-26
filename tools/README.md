### Tools directory

The `tools` directory contains the source code used for benchmarking:

- `tools/diamond-types`: Snapshot of [diamond types](https://github.com/josephg/diamond-types), which contains our optimised implementation of the algorithm. This mirror of the codebase includes hooks for benchmarking that we use to generate the datasets in this paper. Diamond types also contains CLI tools needed to extract traces from a git repository, and query and extract raw data from .dt data files.
- `tools/diamond-types/crates/paper-stats`: Child crate which analyses some internal stats of DT, used in the paper.
- `tools/bench-yjs`: Memory and CPU time benchmark for yjs
- `tools/crdt-converter`: Converter tool to convert editing traces (in .json format) to yjs and automerge formats. (Conversion uses the Yrs fork of yjs)
- `tools/ot-bench`: Reference implementation of operational transform, and benchmark thereof. This implementation uses memoization to avoid excessive transform calls - which improves performance at a cost of memory usage.
- `tools/paper-benchmarks`: Benchmarks for various CRDT implementations. The only benchmark result used from this is the benchmarks for automerge - both CPU time and memory benchmarks. This repository also contains benchmarks for some other CRDTs - including Cola, Yrs and JSONJoy. These CRDTs were not included in the final report to save space.

Diamond-types has been cloned at hash 4d3ca0e2f294f0699a5c9454dd879639a383bee
