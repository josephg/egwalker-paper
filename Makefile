.phony: all

DT_TOOL=tools/diamond-types/target/release/dt
CONV_TOOL=tools/crdt-converter/target/release/crdt-converter

$(DT_TOOL):
	cd tools/diamond-types; cargo build --release -p dt-cli

$(CONV_TOOL):
	cd tools/crdt-converter; cargo build --release

ALL_JSON = datasets/S1.json datasets/S2.json datasets/S3.json datasets/C1.json datasets/C2.json datasets/A1.json datasets/A2.json
ALL_DT = datasets/S1.dt datasets/S2.dt datasets/S3.dt datasets/C1.dt datasets/C2.dt datasets/A1.dt datasets/A2.dt
ALL_YJS = datasets/S1.yjs datasets/S2.yjs datasets/S3.yjs datasets/C1.yjs datasets/C2.yjs datasets/A1.yjs datasets/A2.yjs
ALL_AM = datasets/S1.am datasets/S2.am datasets/S3.am datasets/C1.am datasets/C2.am datasets/A1.am datasets/A2.am

DIAGRAMS = diagrams/timings.svg diagrams/memusage.svg diagrams/filesize_full.svg diagrams/filesize_smol.svg diagrams/ff.svg

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

# results/js.json \
# results/xf-clownschool-ff.json \
# results/xf-clownschool-noff.json \
# results/xf-git-makefile-ff.json \
# results/xf-git-makefile-noff.json \
# results/xf-node_nodecc-ff.json \
# results/xf-node_nodecc-noff.json \

DT_BENCHES = \
	tools/diamond-types/target/criterion/dt/merge_norm/S1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/merge_norm/S2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/merge_norm/S3/base/estimates.json \
	tools/diamond-types/target/criterion/dt/merge_norm/C1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/merge_norm/C2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/merge_norm/A1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/merge_norm/A2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/ff_off/S1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/ff_off/S2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/ff_off/S3/base/estimates.json \
	tools/diamond-types/target/criterion/dt/ff_off/C1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/ff_off/C2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/ff_off/A1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/ff_off/A2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/opt_load/S1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/opt_load/S2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/opt_load/S3/base/estimates.json \
	tools/diamond-types/target/criterion/dt/opt_load/C1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/opt_load/C2/base/estimates.json \
	tools/diamond-types/target/criterion/dt/opt_load/A1/base/estimates.json \
	tools/diamond-types/target/criterion/dt/opt_load/A2/base/estimates.json \

DT_CRDT_BENCHES = \
	tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/S1/base/estimates.json \
	tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/S2/base/estimates.json \
	tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/S3/base/estimates.json \
	tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/C1/base/estimates.json \
	tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/C2/base/estimates.json \
	tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/A1/base/estimates.json \
	tools/diamond-types/target/criterion/dt-crdt/process_remote_edits/A2/base/estimates.json \

AM_BENCHES = \
	tools/paper-benchmarks/target/criterion/automerge/remote/S1/base/estimates.json \
	tools/paper-benchmarks/target/criterion/automerge/remote/S2/base/estimates.json \
	tools/paper-benchmarks/target/criterion/automerge/remote/S3/base/estimates.json \
	tools/paper-benchmarks/target/criterion/automerge/remote/C1/base/estimates.json \
	tools/paper-benchmarks/target/criterion/automerge/remote/C2/base/estimates.json \
	tools/paper-benchmarks/target/criterion/automerge/remote/A1/base/estimates.json \
	tools/paper-benchmarks/target/criterion/automerge/remote/A2/base/estimates.json \

OT_BENCHES = \
	tools/ot-bench/target/criterion/ot/S1/base/estimates.json \
	tools/ot-bench/target/criterion/ot/S2/base/estimates.json \
	tools/ot-bench/target/criterion/ot/S3/base/estimates.json \
	tools/ot-bench/target/criterion/ot/C1/base/estimates.json \
	tools/ot-bench/target/criterion/ot/C2/base/estimates.json \
	tools/ot-bench/target/criterion/ot/A1/base/estimates.json \
	tools/ot-bench/target/criterion/ot/A2/base/estimates.json \

ALL_BENCHES = $(DT_BENCHES) $(DT_CRDT_BENCHES) $(AM_BENCHES) $(OT_BENCHES)

all: $(ALL_JSON) $(DIAGRAMS)

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

datasets/%.json: datasets/%.dt $(DT_TOOL)
	$(DT_TOOL) export-trace $< -o $@

datasets/%.yjs: datasets/%.json $(CONV_TOOL)
	$(CONV_TOOL) -y $<

datasets/%.am datasets/%-uncompressed.am &: datasets/%.json $(CONV_TOOL)
	$(CONV_TOOL) -a $<


ALL_DT = datasets/

results/dt_memusage.json results/dataset_stats.json &: $(ALL_DT) tools/diamond-types/crates/paper-stats/src/main.rs
	cd tools/diamond-types; cargo run --release -p paper-stats --features memusage

results/dtcrdt_memusage.json: $(ALL_DT) tools/diamond-types/crates/run_on_old/src/main.rs
	cd tools/diamond-types; cargo run --release -p run_on_old --features memusage

results/automerge_memusage.json: $(ALL_AM)
	cd tools/paper-benchmarks; cargo run --features memusage --release

results/ot_memusage.json: $(ALL_JSON) tools/ot-bench/src/main.rs
	cd tools/ot-bench; cargo run --features memusage --release

results/yjs_memusage.json: $(ALL_YJS)
	cd tools/bench-yjs; node bench-memusage.js

results/js.json: $(ALL_YJS)
	cd tools/bench-yjs; node bench-remote.js

$(DT_BENCHES) &: $(ALL_DT)
	cd tools/diamond-types; ./bench.sh

$(DT_CRDT_BENCHES) &: $(ALL_DT)
	cd tools/diamond-types; ./bench-runonold.sh

$(AM_BENCHES) &: $(ALL_AM)
	cd tools/paper-benchmarks && ./bench.sh

$(OT_BENCHES) &: $(ALL_JSON)
	cd tools/ot-bench && ./bench.sh

results/timings.json results/yjs_am_sizes.json &: results/js.json $(ALL_YJS) $(ALL_AM) $(ALL_BENCHES)
	node collect.js


$(DIAGRAMS) &: $(ALL_RESULTS)
	cd svg-plot; node render.js

reg-text.pdf: reg-text.typ charts.typ $(DIAGRAMS) $(ALL_RESULTS)
	typst compile reg-text.typ
