# Replayable Event Graph paper

This folder / repository contains everything needed to produce the event graph paper, including reproducing all contained results.

A rough breakdown of the stuff contained here:

- `tools/`: A series of implementations of various code used for data conversion and benchmarking. In particular:
  - `tools/diamond-types`: Snapshot of [diamond types](https://github.com/josephg/diamond-types), which contains our optimised implementation of the algorithm. This mirror of the codebase includes hooks for benchmarking that we use to generate the datasets in this paper. Diamond types also contains CLI tools needed to extract traces from a git repository, and query and extract raw data from .dt data files.
  - `tools/bench-yjs`: Memory and CPU time benchmark for yjs
  - `tools/crdt-converter`: Converter tool to convert editing traces (in .json format) to yjs and automerge formats. (Conversion uses the Yrs fork of yjs)
  - `tools/ot-bench`: Reference implementation of operational transform, and benchmark thereof. This implementation uses memoization to avoid excessive transform calls - which improves performance at a cost of memory usage.
  - `tools/paper-benchmarks`: Benchmarks for various CRDT implementations. The only benchmark result used from this is the benchmarks for automerge - both CPU time and memory benchmarks. This repository also contains benchmarks for some other CRDTs - including Cola, Yrs and JSONJoy. These CRDTs were not included in the final report to save space.
- `results/`: This folder contains all benchmarking results, in JSON format. The files here are generated from various scripts. See the included README.md for more details.
- `datasets/`: The editing traces (datasets) used in this paper. The raw datasets are contained in `datasets/raw` and all other files are generated (extracted) from the raw datasets using some scripts in `datasets/`. See included README.md file for details.
- `egwalker-reference`: This is a reference implementation of the egwalker algorithm described in this paper, written in typescript.


The paper itself is generated as follows:

- `svg-plot`: This tool generates charts in SVG format in the `diagrams/` folder from JSON data in `results/`
- `reg-text.typ`: [Typst](https://typst.app/) source for the paper itself.

The paper text is copyright of the authors. All rights reserved unless otherwise indicated.

The raw editing traces are available at [josephg/editing-traces](https://github.com/josephg/editing-traces). They are mostly licensed under various creative commons licenses. See that repository for details.

All source code (Code in `tools/` folder) is provided herein is licensed under the ISC license:

---

ISC License

Copyright 2024 Joseph Gentle

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.