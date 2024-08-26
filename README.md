# Collaborative Text Editing with Eg-walker: Better, Faster, Smaller

This folder / repository contains everything needed to produce the Egwalker paper, including reproducing all contained results.

A rough breakdown of the files and folders:

- `tools/`: A series of implementations of various code used for data conversion and benchmarking. See below for details.
- `results/`: This folder contains all benchmarking results, in JSON format. The files here are generated from various scripts. See the included README.md for more details.
- `datasets/`: The editing traces (datasets) used in this paper. The raw datasets are contained in `datasets/raw` and all other files are generated from the raw datasets.
- `egwalker-reference`: This is a reference implementation of the egwalker algorithm described in this paper, written in typescript.
- `svg-plot`: This tool generates charts in SVG format in the `diagrams/` folder from JSON data in `results/`.
- `reg-text.typ`: [Typst](https://typst.app/) source for the paper itself. The paper embeds SVGs from `diagrams/` and uses some stats from the `results/` directory for tables.


## Reproducing our results

This repository contains everything you need to fully reproduce all results in the paper.

### Step 0: Prerequisites

**OS:** We have run all our benchmarks on linux, but the following steps should work on other broadly supported operating systems (like macos).

**Tools:** You will need the following tools installed on your computer:

- *Rust compiler & toolchain*: Any "recent" version of rust should work. The published version of the paper used rust 1.78. The easiest way to install rust is via [rustup](https://rustup.rs/).
- *NodeJS*: Nodejs is only used for scripting - like extracting benchmarking results into 'clean' JSON files and generating the charts used in the paper.

To get started, you'll need a recent version of nodejs and rust installed on your system. We used node v21 and rust 1.78. You will also need at least 44GB of RAM to run the automerge C2 benchmark.

This process has only been tested on linux, but it *should* work on other broadly supported platforms (like macos) too.

Then run:

```
$ make clean
$ make
```

It takes about 24 hours to run all of the benchmarks. Almost all of this time is taken up by:

- automerge/C1 (3hrs for 100 samples)
- automerge/C2 (11.5hrs for 100 samples)
- OT/A2 (10 hours for 10 samples).

The results we used to generate the paper are stored as a set of JSON files in `results/`. `make clean` will remove all current benchmark results.

On MacOS, you may need to install gnumake and then invoke the makefile with `gmake` instead. YMMV.

The makefile also contains the commands to re-convert the datasets in datasets/raw to JSON, Yjs and Automerge formats. This conversion has already been done (and the results are checked in to this repository). But if you want to regenerate them for any reason, you can delete datasets/* and run `make` again.

---

The paper text is copyright of the authors. All rights reserved unless otherwise indicated.

The raw editing traces are available at [josephg/editing-traces](https://github.com/josephg/editing-traces). They are mostly licensed under various creative commons licenses. See that repository for details.

All source code (Code in `tools/` folder) is provided herein is licensed under the ISC license:

---

### Tools directory

The `tools` directory contains the source code used for benchmarking:

- `tools/diamond-types`: Snapshot of [diamond types](https://github.com/josephg/diamond-types), which contains our optimised implementation of the algorithm. This mirror of the codebase includes hooks for benchmarking that we use to generate the datasets in this paper. Diamond types also contains CLI tools needed to extract traces from a git repository, and query and extract raw data from .dt data files.
- `tools/diamond-types/crates/paper-stats`: Child crate which analyses some internal stats of DT, used in the paper.
- `tools/bench-yjs`: Memory and CPU time benchmark for yjs
- `tools/crdt-converter`: Converter tool to convert editing traces (in .json format) to yjs and automerge formats. (Conversion uses the Yrs fork of yjs)
- `tools/ot-bench`: Reference implementation of operational transform, and benchmark thereof. This implementation uses memoization to avoid excessive transform calls - which improves performance at a cost of memory usage.
- `tools/paper-benchmarks`: Benchmarks for various CRDT implementations. The only benchmark result used from this is the benchmarks for automerge - both CPU time and memory benchmarks. This repository also contains benchmarks for some other CRDTs - including Cola, Yrs and JSONJoy. These CRDTs were not included in the final report to save space.


ISC License

Copyright 2024 Joseph Gentle

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.