.phony: all cargo_magic clean
all: reg-text.pdf
# all: $(ALL_JSON) $(DIAGRAMS)

clean:
	rm -f results/*
	rm -rf target/criterion
	cd tools/diamond-types && cargo clean
	cd tools/crdt-converter && cargo clean
	cd tools/ot-bench && cargo clean
	cd tools/paper-benchmarks && cargo clean

cargo_magic:

DT_TOOL=tools/diamond-types/target/release/dt
CONV_TOOL=tools/crdt-converter/target/release/crdt-converter

DATASET = S1 S2 S3 C1 C2 A1 A2

ALL_DT = $(patsubst %,datasets/%.dt,$(DATASET))
ALL_JSON = $(patsubst %,datasets/%.json,$(DATASET))
ALL_YJS = $(patsubst %,datasets/%.yjs,$(DATASET))
ALL_AM = $(patsubst %,datasets/%.am,$(DATASET))


DT_BENCHES = \
	$(patsubst %,target/criterion/dt/merge_norm/%/base/estimates.json,$(DATASET)) \
	$(patsubst %,target/criterion/dt/ff_off/%/base/estimates.json,$(DATASET)) \
	$(patsubst %,target/criterion/dt/opt_load/%/base/estimates.json,$(DATASET)) \

DT_CRDT_BENCHES = \
	$(patsubst %,target/criterion/dt-crdt/process_remote_edits/%/base/estimates.json,$(DATASET))

AM_BENCHES = \
	$(patsubst %,target/criterion/automerge/remote/%/base/estimates.json,$(DATASET))

OT_BENCHES = \
	$(patsubst %,target/criterion/ot/%/base/estimates.json,$(DATASET))

ALL_BENCHES = $(DT_BENCHES) $(DT_CRDT_BENCHES) $(AM_BENCHES) $(OT_BENCHES)

# Benchmarks must be run 1 at a time.
.NOTPARALLEL: $(ALL_BENCHES)

ALL_RESULTS = \
	results/automerge_memusage.json \
	results/dtcrdt_memusage.json \
	results/dt_memusage.json \
	results/ot_memusage.json \
	results/yjs_memusage.json \
	results/yjs_am_sizes.json \
	results/dataset_stats.json \
	results/xf-friendsforever-ff.json \
	results/xf-friendsforever-noff.json \
	results/timings.json \

# These result files aren't used directly.
# results/js.json \
# results/xf-clownschool-ff.json \
# results/xf-clownschool-noff.json \
# results/xf-git-makefile-ff.json \
# results/xf-git-makefile-noff.json \
# results/xf-node_nodecc-ff.json \
# results/xf-node_nodecc-noff.json \


DIAGRAMS = diagrams/timings.svg diagrams/memusage.svg diagrams/filesize_full.svg diagrams/filesize_smol.svg diagrams/ff.svg

# ***** Creating datasets

$(DT_TOOL):
	cd tools/diamond-types && cargo build --release -p dt-cli

$(CONV_TOOL):
	cd tools/crdt-converter && cargo build --release

# These all get duplicated different numbers of times, so they're written out in full.
datasets/S1.dt: datasets/raw/automerge-paper.dt | $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n3 -f
datasets/S2.dt: datasets/raw/seph-blog1.dt | $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n3 -f
datasets/S3.dt: datasets/raw/egwalker.dt | $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n1 -f

datasets/C1.dt: datasets/raw/friendsforever.dt | $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n25 -f
datasets/C2.dt: datasets/raw/clownschool.dt | $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n25 -f

datasets/A1.dt: datasets/raw/node_nodecc.dt | $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n1 -f
datasets/A2.dt: datasets/raw/git-makefile.dt | $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n2 -f

# Export dt file -> JSON
datasets/%.json: datasets/%.dt | $(DT_TOOL)
	$(DT_TOOL) export-trace $< -o $@

# Convert JSON file to yjs
datasets/%.yjs: datasets/%.json | $(CONV_TOOL)
	$(CONV_TOOL) -y $<

# Convert JSON file to automerge
datasets/%.am datasets/%-uncompressed.am &: datasets/%.json | $(CONV_TOOL)
	$(CONV_TOOL) -a $<



# ***** Benchmarking and memory usage profiling

# Dataset stats + memory usage for DT
PAPER_STATS_TOOL = tools/diamond-types/target/release/paper-stats

$(PAPER_STATS_TOOL): cargo_magic
	cd tools/diamond-types && cargo build --release -p paper-stats --features memusage

results/dt_memusage.json results/dataset_stats.json &: $(PAPER_STATS_TOOL) $(ALL_DT)
	$<

# Benchmarking for DT
DT_BENCH_TOOL = tools/diamond-types/target/release/bench
$(DT_BENCH_TOOL): cargo_magic
	cd tools/diamond-types && cargo build --release -p bench

target/criterion/dt/%/base/estimates.json: $(DT_BENCH_TOOL) $(ALL_DT)
	@echo "Sleeping for 5 seconds to cool down CPU..."
	@sleep 5
	taskset 0x1 nice -10 $< --bench $*


# Memory usage for dt-crdt
DTCRDT_MEMUSAGE_TOOL = tools/diamond-types/target/memusage/run_on_old

$(DTCRDT_MEMUSAGE_TOOL): cargo_magic
	cd tools/diamond-types && cargo build --profile memusage -p run_on_old --features memusage
results/dtcrdt_memusage.json: $(DTCRDT_MEMUSAGE_TOOL) $(ALL_DT)
	$<

# Benchmarking for dt-crdt
DTCRDT_BENCH_TOOL = tools/diamond-types/target/release/run_on_old

$(DTCRDT_BENCH_TOOL): cargo_magic
	cd tools/diamond-types && cargo build --release -p run_on_old --features bench

target/criterion/dt-crdt/%/base/estimates.json: $(DTCRDT_BENCH_TOOL) $(ALL_DT)
	@echo "Sleeping for 5 seconds to cool down CPU..."
	@sleep 5
	taskset 0x1 nice -10 $< --bench $*


# Memory usage for automerge
AM_MEMUSAGE_TOOL = tools/paper-benchmarks/target/memusage/paper-benchmarks
$(AM_MEMUSAGE_TOOL): cargo_magic
	cd tools/paper-benchmarks && cargo build --profile memusage --features memusage

results/automerge_memusage.json: $(AM_MEMUSAGE_TOOL) $(ALL_AM)
	$<

# Benchmarks for automerge
PAPER_BENCH_TOOL = tools/paper-benchmarks/target/release/paper-benchmarks
$(PAPER_BENCH_TOOL): cargo_magic
	cd tools/paper-benchmarks && cargo build --release --features bench

target/criterion/automerge/%/base/estimates.json: $(ALL_AM) | $(PAPER_BENCH_TOOL)
	@echo "Sleeping for 5 seconds to cool down CPU..."
	@sleep 5
	taskset 0x1 nice -10 $< --bench $*


# Memory usage for OT
OT_MEMUSAGE_TOOL = tools/ot-bench/target/memusage/ot-bench
$(OT_MEMUSAGE_TOOL): cargo_magic
	cd tools/ot-bench && cargo build --profile memusage --features memusage

results/ot_memusage.json: $(OT_MEMUSAGE_TOOL) $(ALL_JSON)
	$<

# Benchmarks for OT
OT_BENCH_TOOL = tools/ot-bench/target/release/ot-bench
$(OT_BENCH_TOOL): cargo_magic
	cd tools/ot-bench && cargo build --release --features bench

target/criterion/ot/%/base/estimates.json: $(OT_BENCH_TOOL) $(ALL_AM)
	@echo "Sleeping for 5 seconds to cool down CPU..."
	@sleep 5
	taskset 0x1 nice -10 $< --bench $*



# YJS

%/node_modules: %/package.json
	@echo "Installing Node.js dependencies in $*..."
	cd $* && npm install
	@touch $@

results/yjs_memusage.json: tools/bench-yjs/node_modules $(ALL_YJS)
	cd tools/bench-yjs && node --expose-gc bench-memusage.js

results/js.json: $(ALL_YJS)
	cd tools/bench-yjs && node bench-remote.js

# tools/diamond-types/target/criterion/dt/%/base/estimates.json: $(ALL_DT)
# 	cd tools/diamond-types && ./bench.sh $*

# tools/diamond-types/target/criterion/dt-crdt/%/base/estimates.json: $(ALL_DT)
# 	cd tools/diamond-types && ./bench-runonold.sh $*

# tools/paper-benchmarks/target/criterion/automerge/%/base/estimates.json: $(ALL_AM)
# 	cd tools/paper-benchmarks && ./bench.sh $*

# tools/ot-bench/target/criterion/ot/%/estimates.json: $(ALL_JSON)
# 	cd tools/ot-bench && ./bench.sh $*


results/timings.json results/yjs_am_sizes.json &: results/js.json $(ALL_YJS) $(ALL_AM) $(ALL_BENCHES)
	node collect.js

$(DIAGRAMS) &: svg-plot/node_modules $(ALL_RESULTS)
	cd svg-plot && node render.js

# This is the master target.
reg-text.pdf: reg-text.typ $(DIAGRAMS) $(ALL_RESULTS)
	typst compile reg-text.typ

paper_data_anon.zip: #| $(ALL_RESULTS)
	zip -vr $@ README_anon.md Makefile_anon results tools feathertail-reference datasets -x '*node_modules/*' -x '*target/*' -x '*.idea/*'