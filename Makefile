.phony: all

all: $(ALL_JSON) $(DIAGRAMS)

DT_TOOL=tools/diamond-types/target/release/dt
CONV_TOOL=tools/crdt-converter/target/release/crdt-converter

$(DT_TOOL):
	cd tools/diamond-types && cargo build --release -p dt-cli

$(CONV_TOOL):
	cd tools/crdt-converter && cargo build --release

DATASET = S1 S2 S3 C1 C2 A1 A2

ALL_DT = $(patsubst %,datasets/%.dt,$(DATASET))
ALL_JSON = $(patsubst %,datasets/%.json,$(DATASET))
ALL_YJS = $(patsubst %,datasets/%.yjs,$(DATASET))
ALL_AM = $(patsubst %,datasets/%.am,$(DATASET))


DT_BENCHES = \
	$(patsubst %,tools/diamond-types/target/criterion/dt/merge_norm/%/base/estimates.json,$(DATASET)) \
	$(patsubst %,tools/diamond-types/target/criterion/dt/ff_off/%/base/estimates.json,$(DATASET)) \
	$(patsubst %,tools/diamond-types/target/criterion/dt/opt_load/%/base/estimates.json,$(DATASET)) \

DT_CRDT_BENCHES = \
	$(patsubst %,tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/%/base/estimates.json,$(DATASET))

AM_BENCHES = \
	$(patsubst %,tools/paper-benchmarks/target/criterion/automerge/remote/%/base/estimates.json,$(DATASET))

OT_BENCHES = \
	$(patsubst %,tools/ot-bench/target/criterion/ot/%/base/estimates.json,$(DATASET))

ALL_BENCHES = $(DT_BENCHES) $(DT_CRDT_BENCHES) $(AM_BENCHES) $(OT_BENCHES)

ALL_RESULTS = \
	results/timings.json \
	results/automerge_memusage.json \
	results/dtcrdt_memusage.json \
	results/dt_memusage.json \
	results/ot_memusage.json \
	results/yjs_memusage.json \
	results/yjs_am_sizes.json \
	results/dataset_stats.json \
	results/xf-friendsforever-ff.json \
	results/xf-friendsforever-noff.json \

# These result files aren't used directly.
# results/js.json \
# results/xf-clownschool-ff.json \
# results/xf-clownschool-noff.json \
# results/xf-git-makefile-ff.json \
# results/xf-git-makefile-noff.json \
# results/xf-node_nodecc-ff.json \
# results/xf-node_nodecc-noff.json \


DIAGRAMS = diagrams/timings.svg diagrams/memusage.svg diagrams/filesize_full.svg diagrams/filesize_smol.svg diagrams/ff.svg


# These all get duplicated different numbers of times, so they're written out in full.
datasets/S1.dt: datasets/raw/automerge-paper.dt $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n3 -f
datasets/S2.dt: datasets/raw/seph-blog1.dt $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n3 -f
datasets/S3.dt: datasets/raw/egwalker.dt $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n1 -f

datasets/C1.dt: datasets/raw/friendsforever.dt $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n25 -f
datasets/C2.dt: datasets/raw/clownschool.dt $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n25 -f

datasets/A1.dt: datasets/raw/node_nodecc.dt $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n1 -f
datasets/A2.dt: datasets/raw/git-makefile.dt $(DT_TOOL)
	$(DT_TOOL) bench-duplicate $< -o $@ -n2 -f

# Export dt file -> JSON
datasets/%.json: datasets/%.dt $(DT_TOOL)
	$(DT_TOOL) export-trace $< -o $@

# Convert JSON file to yjs
datasets/%.yjs: datasets/%.json $(CONV_TOOL)
	$(CONV_TOOL) -y $<

# Convert JSON file to automerge
datasets/%.am datasets/%-uncompressed.am &: datasets/%.json $(CONV_TOOL)
	$(CONV_TOOL) -a $<


results/dt_memusage.json results/dataset_stats.json &: $(ALL_DT) tools/diamond-types/crates/paper-stats/src/main.rs
	cd tools/diamond-types && cargo run --release -p paper-stats --features memusage

results/dtcrdt_memusage.json: $(ALL_DT) tools/diamond-types/crates/run_on_old/src/main.rs
	cd tools/diamond-types && cargo run --release -p run_on_old --features memusage

results/automerge_memusage.json: $(ALL_AM)
	cd tools/paper-benchmarks && cargo run --features memusage --release

results/ot_memusage.json: $(ALL_JSON) tools/ot-bench/src/main.rs
	cd tools/ot-bench && cargo run --features memusage --release

%/node_modules: %/package.json
	@echo "Installing Node.js dependencies in $*..."
	cd $* && npm install
	@touch $@

results/yjs_memusage.json: tools/bench-yjs/node_modules $(ALL_YJS)
	cd tools/bench-yjs && node --expose-gc bench-memusage.js

results/js.json: $(ALL_YJS)
	cd tools/bench-yjs && node bench-remote.js

tools/diamond-types/target/criterion/dt/%/base/estimates.json: $(ALL_DT)
	cd tools/diamond-types && ./bench.sh $*

tools/diamond-types/target/criterion/dt-crdt/%/base/estimates.json: $(ALL_DT)
	cd tools/diamond-types && ./bench-runonold.sh $*

tools/paper-benchmarks/target/criterion/automerge/%/base/estimates.json: $(ALL_AM)
	cd tools/paper-benchmarks && ./bench.sh $*

tools/ot-bench/target/criterion/ot/%/estimates.json: $(ALL_JSON)
	cd tools/ot-bench && ./bench.sh $*

.NOTPARALLEL: $(ALL_BENCHES)

results/timings.json results/yjs_am_sizes.json &: results/js.json $(ALL_YJS) $(ALL_AM) $(ALL_BENCHES)
	node collect.js


$(DIAGRAMS) &: svg-plot/node_modules $(ALL_RESULTS)
	cd svg-plot && node render.js

reg-text.pdf: reg-text.typ charts.typ $(DIAGRAMS) $(ALL_RESULTS)
	typst compile reg-text.typ
