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

### Short version:

Install rust and nodejs. There are two options to run all our benchmarks.

Option 1: Use make:

```
make clean
make
```

Option 2: Use included shell scripts:

```
./step1-prepare.sh
./step2-bench.sh
node collect.js
```

Note benchmarks take ~12 hours or so to run. (Almost all of this time is the OT/A2 benchmark - which takes about 1 hour per sample, and we collect 10 samples).

You can use `git diff` on `results/timings.json` (and other files) to see how your experimental results compare to ours.


### Step 0: Prerequisites

**Tools:** You will need the following tools installed on your computer:

- *Rust compiler & toolchain*: Any "recent" version of rust should work. The published version of the paper used rust 1.78. The easiest way to install rust is via [rustup](https://rustup.rs/).
- *NodeJS*: Nodejs is only used for scripting - like extracting benchmarking results into 'clean' JSON files and generating the charts used in the paper.

We used rust 1.78 and nodejs v21 when generating the results in the current version of the paper.

This process has only been tested on linux, but it *should* work on other broadly supported platforms (like macos) too.




### Step 1: Preparing the data (OPTIONAL)

The 7 raw editing traces are checked into the repository at `datasets/raw`. These files are stored in the diamond types packed binary format.

Before the benchmarks can be run, we do the following preprocessing steps on these files:

1. The traces are "duplicated" to make them all about the same size. (For example, `datasets/raw/friendsforever.dt` is duplicated 25 times and repacked as `datasets/C1.dt`).
2. The datasets are exported as JSON
3. The JSON traces are converted to "native" Yjs and Automerge formats.

Conversion is slow, and **this step is optional**. For convenience, the converted files are already checked into git in the datasets directory.

The first 2 steps make use of a CLI tool in `tools/diamond-types/crates/dt-cli`. The final step uses `tools/crdt-converter`. Both tools are built automatically.

You can re-run step 1 as follows (time taken: 1 hour or so):

```
rm datasets/*
./step1-prepare.sh
```

Output: `datasets/*.am, *.yjs, *.json`


### Step 2: Benchmarking

There's a series of benchmarks to run. For each algorithm, for each editing trace, we do the following tests:

- Measure memory usage
- Measure time taken to merge in the editing trace (as if from a remote peer)

Algorithms:

- DT (our optimised reference egwalker implementation)
- DT-CRDT (our reference CRDT implementation)
- Automerge
- Yjs
- Yrs (Yjs rust port)
- OT (our reference OT implementation)

**Note:** Our OT implementation takes 1 hour to replay the A2 editing trace.

We consider the core benchmark in the paper to be the "remote time" - which is the amount of time (& memory usage) taken when merging all remote edits over the network.

We do this test for automerge, yjs (/ yrs), diamond-types (our optimized eg-walker implementation), dtcrdt (our reference CRDT implementation) and our reference OT implementation.

Each speed benchmark also has a corresponding memory usage benchmark, initiated with a different command.

Measure memory usage (time estimate: 1h10min):

```
./step2a-memusage.sh
```

Benchmark remote merging across all algorithms (time estimate: **12 hours**):

```
./step2b-benchmarks.sh
```

Output: Lots of files in `results/`. Criterion benchmarks are stored in directories like `target/criterion/automerge/remote/A1/`


### Step 3: Collation

Most of the benchmarks are done using [Criterion.rs](https://github.com/bheisler/criterion.rs). Criterion results are stored in JSON files like `target/criterion/automerge/remote/A1/base/estimates.json`. (Criterion also records the time taken for every sample, and various other cool things! Take a look at `target/criterion/report/index.html` in your browser!)

The next step is pulling that data out into simple, usable json file.

Time taken: 1 second

```
node collect.js
```

This creates `results/timings.json`, which is used for many of the charts. It also emits `results/yjs_am_sizes.json` containing the file sizes for the yjs & automerge binary formats.

Our experimental results are checked in to git. If you're trying to reproduce our experimental results, you can run `git diff results/timings.json` to see how your remote merge times differed from ours.


### Step 4: Generate charts (OPTIONAL)

Our diagrams are generated by our `svg-plot` tool. You can regenerate them like this:

```
cd svg-plot
npm i # only needed once to install dependencies

node render.js
```

This tool outputs a set of SVGs in `diagrams/*.svg`

### Step 5: Generate the paper (OPTIONAL)

Our paper is written using [typst](https://typst.app) (a modern replacement for LaTeX). You can install typst using `cargo install typst-cli` then generate the paper with this command

```
typst compile reg-text.typ
```

---

The paper text is copyright of the authors. All rights reserved unless otherwise indicated.

Most of the raw editing traces are also available at [josephg/editing-traces](https://github.com/josephg/editing-traces). See that repository for details & licensing information.

All source code (Code in `tools/` folder) is provided herein is licensed under the ISC license:

ISC License

Copyright 2024 Joseph Gentle

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.