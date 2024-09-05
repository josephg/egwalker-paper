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
./step0-clean.sh
./step1-prepare.sh
./step2a-memusage.sh
./step2b-benchmarks.sh
node collect.js
```

Note benchmarks take ~12 hours or so to run. (Almost all of this time is the OT/A2 benchmark - which takes about 1 hour per sample, and we collect 10 samples).

You can use `git diff` on `results/timings.json` (and other files) to see how your experimental results compare to ours.


### Terminology

- *Diamond-types* (or sometimes *DT*) is the name of our optimized rust eg-walker implementation.
- *DT-CRDT* is the name of our reference CRDT implementation.


### Step 0: Prerequisites (20 human-minutes)

**Tools:** You will need the following tools installed on your computer:

- *Rust compiler & toolchain*: Any "recent" version of rust should work. The published version of the paper used rust 1.78. The easiest way to install rust is via [rustup](https://rustup.rs/).
- *NodeJS*: Nodejs is only used for scripting - like extracting benchmarking results into 'clean' JSON files and generating the charts used in the paper.
- *(Optional)*: GNU Make 4.3. We have alternative shell scripts if you don't have make available, but its less convenient.

We used rust 1.80 and nodejs v21 when generating the results in the current version of the paper.

This process has only been tested on linux, but it *should* work on other broadly supported platforms (like macos) too.




### Step 1: Preparing the data (OPTIONAL) (1 human minute + 4 compute-hour)

The 7 raw editing traces are checked into the repository at `datasets/raw`. These files are stored in the diamond types packed binary format.

Before the benchmarks can be run, we do the following preprocessing steps on these files:

1. The traces are "duplicated" to make them all about the same size. (For example, `datasets/raw/friendsforever.dt` is duplicated 25 times and repacked as `datasets/C1.dt`).
2. The datasets are exported as JSON
3. The JSON traces are converted to "native" Yjs and Automerge formats.

Conversion is slow, and **this step is optional**. For convenience, the converted files are already checked into git in the datasets directory.

The first 2 steps make use of a CLI tool in `tools/diamond-types/crates/dt-cli`. The final step uses `tools/crdt-converter`. Both tools are built automatically.

You can re-run step 1 as follows (time taken: 4 hours or so):

```
rm datasets/*
./step1-prepare.sh
```

Output: `datasets/*.am, *.yjs, *.json`

These files *should* be byte-for-byte identical with the files distributed via this git repository. Ie, after regenerated these files, `git status` should report no changes.

The size of the files produced during this step are measured to produce *Figure 11* and *Figure 12* on page 12 in the paper.

This process takes an unreasonably long time to run! Sorry! We just didn't optimize this process much, since you only need to do this once. You can also run these scripts in parallel using make. For example:

```
make -j16 all_datasets
```

(The `all_datasets` make rule corresponds to this conversion step.)


### Step 2: Benchmarking (2 human minutes + 12 computer hours)

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

Output: Lots of files in `results/`. Criterion benchmarks are stored in directories like `target/criterion/automerge/remote/A1/`.


### Step 3: Collation

Most of the benchmarks are done using [Criterion.rs](https://github.com/bheisler/criterion.rs). Criterion results are stored in JSON files like `target/criterion/automerge/remote/A1/base/estimates.json`. (Criterion also records the time taken for every sample, and various other cool things! Take a look at `target/criterion/report/index.html` in your browser!)

The next step is pulling that data out into simple, usable json file.

Time taken: 1 second

```
node collect.js
```

This creates `results/timings.json`, which is used for many of the charts. It also emits `results/yjs_am_sizes.json` containing the file sizes for the yjs & automerge binary formats.

Our experimental results are checked in to git. If you're trying to reproduce our experimental results, you can run `git diff results/timings.json` to see how your remote merge times differed from ours.


### Step 4: Generate charts

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

### Step 6: Validate our claims (30 human minutes)

After you have done all of the above steps, you can compare your experimental results to ours.

Note that some of the most important claims in the paper are properties of the algorithm, not something we can benchmark. The biggest one is the claim that a peer can emit editing events directly without reference to any metadata.

This falls out of the algorithm (since there's no equivalent to a CRDT prepare function). But we can't measure it.

However, you should still be able to validate all our performance claims!

`diagrams/timings.svg` should match *Figure 8* on page 10. Obviously, your computer may be faster or slower than ours. But the relative speed of the various algorithms should remain intact. This diagram is generated from `results/timings.json`. You can compare the raw benchmarking results with ours using `git diff results/timings.json`.

`diagrams/memusage.svg` should match *Figure 10* on page 11. Run-to-run variance in this test should be very small. This diagram is generated from files with the pattern of `results/(alg)_memusage.json`.

`diagrams/filesize_full.svg` and `diagrams/filesize_smol.svg` should match *Figure 11* and *Figure 12* on page 12. These diagrams are generated from the size of the files in the `datasets/` directory. The "base sizes" (the size of all raw text) is shown in `results/dataset_stats.json`, along with various other stats. (This file is generated during step 2a from running `tools/diamond-types/target/release/paper-stats`).

`diagrams/plot_ff.svg` was ultimately cut from the paper to keep the size down. You can ignore this one!

*Table 1* on page 15 in the paper is generated directly from `results/dataset_stats.json`. This file is generated from the source code in [`tools/diamond-types/crates/paper-stats/src/main.rs`](tools/diamond-types/crates/paper-stats/src/main.rs). The columns are populated as follows:

- *repeats*: Hardcoded in the table. But these numbers should match the equivalent `-n3` / `-n25` / etc numbers in the calls to `bench-duplicate` from `step1-prepare.sh` and `Makefile`.
- *Events (k)*: `total_keystrokes` field from dataset_stats. Our egwalker implementation treats every single-character insert or delete as a distinct event. (Events are eagerly run-length encoded throughout the code for performance, but semantically, each insert or delete of a single character is distinct.)
- *Avg Concurrency*: `concurrency_estimate` from dataset_stats. This estimate is calculated by taking the mean of the number of other events which are concurrent with each event in the trace. Code for this is [in estimate_concurrency in graph/tools.rs](tools/diamond-types/src/causalgraph/graph/tools.rs).
- *Graph Runs* is calculated by looking at the length of the run-length encoded graph data structure. The graph is stored as a list. Each item in the list corresponds to a sequence of events such that each event *n* after the first event in the range has parents of *n - 1*. How many such runs do we need to encode the graph? This is populated from `graph_rle_size` in dataset_stats.
- *Authors* is the number of unique authors who contributed to the trace. This is mostly not recorded in the files at all.
- *Chars remaining* is calculated from `data.final_doc_len_chars / data.num_insert_keystrokes`, as a percentage.
- *Final size* is `data.final_doc_len_utf8 / 1024`.


# Reusing our editing traces

The easiest way to use our editing traces is by using the json formatted versions in `datasets`. These files contain lists of editing transactions. Each transaction contains a non-empty set of *patches* (edits to the document) made by some user agent at some point in time. (Ie, after some other set of transactions have been merged). The file format is described in the [`editing-traces` repository](https://github.com/josephg/editing-traces/tree/master/concurrent_traces).

If you want to benchmark a CRDT using these editing traces, you need to convert them to your CRDT's local format. We do this by simulating (in memory) a set of collaborating peers. The peers fork and merge their changes. See [tools/crdt-converter/src/main.rs](tools/crdt-converter/src/main.rs) for code to perform this process using automerge and yjs (yrs).

This simulation process is usually very slow, but that doesn't really matter. Our benchmarks take this converted file and merge it directly.


---

The paper text is copyright of the authors. All rights reserved unless otherwise indicated.

Most of the raw editing traces are also available at [josephg/editing-traces](https://github.com/josephg/editing-traces). See that repository for details & licensing information.

All source code (Code in `tools/` folder) is provided herein is licensed under the ISC license:

ISC License

Copyright 2024 Joseph Gentle

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.