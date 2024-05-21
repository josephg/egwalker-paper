# Feathertail paper

This folder / repository contains our tools and data used to generate our paper. In particular, this contains:

- Our optimised and reference implementations of Feathertail
- The dataset (dataset/) containing our editing traces
- Our benchmarking tools + scripts
- The results we got when we ran those scripts, in pretty-printed JSON form (results/*.json)


In particular:

- `tools/`: A series of implementations of various code used for data conversion and benchmarking. In particular:
  - `tools/diamond-types`: Our optimised implementation of the algorithm. This mirror of the codebase includes hooks for benchmarking that we use to generate the datasets in this paper, and a CLI tool needed to extract traces from a git repository, and query and extract raw data from .dt data files.
  - `tools/diamond-types/crates/paper-stats`: Child crate which analyses some internal stats of DT, used in the paper.
  - `tools/bench-yjs`: Memory and CPU time benchmark for yjs
  - `tools/crdt-converter`: Converter tool to convert editing traces (in .json format) to yjs and automerge formats. (Conversion uses the Yrs fork of yjs)
  - `tools/ot-bench`: Reference implementation of operational transform, and benchmark thereof. This implementation uses memoization to avoid excessive transform calls - which improves performance at a cost of memory usage.
  - `tools/paper-benchmarks`: Benchmarks for various CRDT implementations. The only benchmark result used from this is the benchmarks for automerge - both CPU time and memory benchmarks. This repository also contains benchmarks for some other CRDTs - including Cola, Yrs and JSONJoy. These CRDTs were not included in the final report to save space.
- `results/`: This folder contains all benchmarking results, in JSON format. The files here are generated from various scripts. See the included README.md for more details.
- `datasets/`: The editing traces (datasets) used in this paper. The raw datasets are contained in `datasets/raw` and all other files are generated (extracted) from the raw datasets using some scripts in `datasets/`. See included README.md file for details.
- `feathertail-reference`: This is a reference implementation of the feathertail algorithm described in this paper, written in typescript.



## Running the benchmarks yourself

This repository contains everything you need to fully reproduce our results.

To get started, you'll need a recent version of nodejs and rust installed on your system. We used node v21 and rust 1.78. You will also need at least 44GB of RAM to run the automerge C2 benchmark. This process has only been tested on linux.

Then run:

```
$ make clean -f Makefile_anon
$ make -f Makefile_anon
```

It takes about 24 hours to run all of the benchmarks. Almost all of this time is taken up by:

- automerge/C1 (3hrs for 100 samples)
- automerge/C2 (11.5hrs for 100 samples)
- OT/A2 (10 hours for 10 samples).

But you can run all the tools individually. Read the makefile to see all the commands run. (Or run `make --dry-run -f Makefile_anon` to see the full list of commands).

The results we used to generate the paper are stored as a set of JSON files in `results/`. `make clean` will remove all current benchmark results.

On MacOS, you may need to install gnumake and then invoke the makefile with `gmake` instead. YMMV.

The makefile also contains the commands to re-convert the datasets in datasets/raw to JSON, Yjs and Automerge formats. This conversion has already been done (and the results are checked in to this repository). But if you want to regenerate them for any reason, you can delete datasets/* and run `make` again.

---

The paper text is copyright of the authors. All rights reserved unless otherwise indicated.

All source code (Code in `tools/` folder) is provided herein is licensed under the ISC license:

---

ISC License

Copyright 2024 (anonymous authors)

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.