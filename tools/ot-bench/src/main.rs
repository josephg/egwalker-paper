use std::collections::HashMap;
use std::fs::File;
use std::io::{BufReader, Write};
use std::ops::Range;
use std::time::Duration;

use criterion::{black_box, Criterion};
use jumprope::{JumpRope, JumpRopeBuf};
use serde::{Deserialize, Serialize};
use smallvec::{SmallVec, smallvec};
use smartstring::alias::String as SmartString;
#[cfg(feature = "memusage")]
use trace_alloc::measure_memusage;

use ot_text::{compose, OpComponent, TextOp};
use ot_text::OpComponent::{Del, Ins, Skip};

use crate::cg::CausalGraph;
use crate::frontier::Frontier;
use crate::ot_text::transform_list;

mod cg;
mod frontier;
mod ot_text;
// mod ot_text_tp2;

// #[derive(Clone, Debug)]
// pub struct SimpleTextOp {
//     pos: usize,
//     del_len: usize,
//     ins_content: SmartString,
// }

#[derive(Clone, Debug, Deserialize)]
pub struct SimpleTextOp(usize, usize, SmartString);

impl From<SimpleTextOp> for TextOp {
    fn from(value: SimpleTextOp) -> Self {
        let mut result = smallvec![];
        if value.0 > 0 {
            // Position.
            result.push(OpComponent::Skip(value.0));
        }
        if value.1 > 0 {
            // Delete operation.
            result.push(OpComponent::Del(value.1));
        } else {
            debug_assert!(!value.2.is_empty());
            result.push(OpComponent::Ins(value.2));
        }

        TextOp(result)
    }
}

fn patches_to_text_op<I: Iterator<Item=SimpleTextOp>>(iter: I) -> TextOp {
    let mut result = TextOp::new();
    for patch in iter {
        let op: TextOp = patch.into();

        // This does a lot of unnecessary allocating, but that should be fine for this test.
        result = compose(&result, &op);
    }
    result
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TraceExportData {
    kind: SmartString,
    end_content: String,
    num_agents: usize,

    txns: Vec<TraceExportTxn>,
}

fn default_dtspan() -> [usize; 2] {
    [0, 0]
}

/// A Txn represents a single user edit in the document.
#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TraceExportTxn {
    parents: SmallVec<[usize; 2]>,
    num_children: usize, // TODO: Consider taking this out.
    agent: usize,
    // time: DateTime<FixedOffset>,
    // op: TextOperation,
    patches: SmallVec<[SimpleTextOp; 2]>,

    #[serde(default = "default_dtspan")]
    _dt_span: [usize; 2],
}



#[derive(Clone, Debug)]
struct OpChunk {
    agent: usize,
    ops: OpSet,
    // op: TextOp,
}

impl From<TraceExportTxn> for OpChunk {
    fn from(txn: TraceExportTxn) -> Self {
        Self {
            agent: txn.agent,
            // op: patches_to_text_op(txn.patches.into_iter()),
            ops: txn.patches.into_iter().map(|patch| patch.into()).collect()
        }
    }
}

// fn xf_many(a: &[TextOp], b: &[TextOp]) -> SmallVec<[TextOp; 2]> {
//
// }


type OpSet = SmallVec<[TextOp; 2]>;
type MemoDict = HashMap<OpKey, OpSet>;
// type MemoDict = HashMap<OpKey, TextOp>;
// type MemoDict = rustc_hash::FxHashMap<OpKey, TextOp>;
// type MemoDict = BTreeMap<OpKey, TextOp>;

#[derive(Clone, Debug)]
struct OperationData {
    graph: CausalGraph,
    end_content: String,
    ops: Vec<OpChunk>,
    dt_span: Vec<Range<usize>>,
    // memo: MemoDict,
}


impl From<TraceExportData> for OperationData {
    fn from(trace: TraceExportData) -> Self {
        let mut graph = CausalGraph::new();
        for (i, txn) in trace.txns.iter().enumerate() {
            graph.push(i, &txn.parents);
        }

        Self {
            graph,
            end_content: trace.end_content,
            dt_span: trace.txns.iter().map(|txn| txn._dt_span[0]..txn._dt_span[1]).collect(),
            ops: trace.txns.into_iter().map(|txn| txn.into()).collect(),
            // memo: Default::default(),
        }
    }
}

fn apply(op: &TextOp, doc: &mut JumpRopeBuf) {
    let mut pos = 0;

    for c in &op.0 {
        match c {
            Skip(n) => pos += n,
            Del(len) => doc.remove(pos .. pos + len),
            Ins(s) => {
                doc.insert(pos, s);
                pos += str_indices::chars::count(s);
                // pos += s.chars().count();
            }
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
struct OpKey {
    idx: usize,
    v: Frontier,
}


impl OperationData {
    // fn op_at_version<'a, 'b: 'a>(&'b self, i: usize, v: &[usize], memo: &'a mut MemoDict) -> &'a TextOp {
    // fn borrow_ops_at_version<R, F: FnOnce(&[TextOp]) -> R>(&self, i: usize, v: &[usize], memo: &mut MemoDict, f: F) -> R {
    fn borrow_ops_at_version<F: FnOnce(&[TextOp])>(&self, i: usize, v: &[usize], memo: &mut MemoDict, f: F) {
        let ops = &self.ops[i].ops;
        let parents = &self.graph.entries[i].parents;

        if v == parents.0.as_slice() {
            // Ok - the operation already matches the expected version.
            f(ops);
            return;
        }

        let key = OpKey {
            idx: i,
            v: Frontier::from_unsorted(v),
        };

        if let Some(ops) = memo.get(&key) {
            f(ops);
        } else {
            // println!("calc {:?} --- {:?} at {:?}", key, self.dt_span[key.idx], key.v.0.iter().map(|v| self.dt_span[*v].clone()).collect::<Vec<_>>());
            let (a_only, added_idx) = self.graph.diff(parents.0.as_slice(), v);
            debug_assert!(a_only.is_empty());

            let mut parent_version = parents.clone();
            let mut ops = ops.clone();

            for other_idx in added_idx {
                // We need to transform op by other_op.

                // This code is pulled into a child function prevent infinite recursion in the compiler.
                fn helper(s: &OperationData, ops: &mut OpSet, is_left: bool, other_idx: usize, v: &[usize], memo: &mut MemoDict) {
                    s.borrow_ops_at_version(other_idx, v, memo, |other_op_at_p| {
                        transform_list(ops, &other_op_at_p, is_left);
                    });
                }

                helper(self, &mut ops, other_idx < i, other_idx, parent_version.0.as_slice(), memo);
                // self.borrow_ops_at_version(other_idx, parent_version.0.as_slice(), memo, |other_op_at_p| {
                //     transform_list(&mut ops, &other_op_at_p, other_idx < i);
                // });
                parent_version.advance_by(&self.graph, other_idx);
            }

            debug_assert_eq!(parent_version.0.as_slice(), v);

            // memo.entry(key).or_insert(op)
            f(&ops);
            memo.insert(key, ops);
        }
    }

    fn doc_at_version(&self, v: &[usize]) -> JumpRopeBuf {
        let mut doc = JumpRopeBuf::new();
        let mut doc_version = Frontier::root();

        let idxs = self.graph.diff(&[], v).1;
        // let num_to_process = idxs.len();
        let mut memo = MemoDict::new();

        // Apply all the operations in order.
        for (_n, i) in idxs.into_iter().enumerate() {
            // println!("n {_n} / {:?}", self.dt_span[i]);
            // if _n % 30 == 0 { println!("n {_n} / {} memo size {:?}", num_to_process, memo.iter().count()); }
            self.borrow_ops_at_version(i, doc_version.0.as_slice(), &mut memo, |ops| {
                for op in ops {
                    apply(op, &mut doc);
                }
            });

            doc_version.advance_by(&self.graph, i);
        }

        doc
    }
}

fn load_data(filename: &str) -> OperationData {
    let file = BufReader::new(File::open(format!("../../datasets/{}.json", filename)).unwrap());
    let trace: TraceExportData = serde_json::from_reader(file).unwrap();

    trace.into()
}

// fn main() {
//     let data = load_data("git-makefilex2");
//     // let data = load_data("git-makefile");
//     // let data = load_data("friendsforeverx40");
//     // let data = load_data("clownschoolx40");
//     // let data = load_data("friendsforever");
//     // dbg!(&data.graph.frontier);
//     // dbg!(&data.ops);
//
//     let result = data.doc_at_version(data.graph.frontier.0.as_slice());
//     // let result = data.doc_at_version(&[172]);
//     let s = result.to_string();
//     // println!("{}", s);
//     // assert_eq!(s, data.end_content);
//
//     // for entry in fs::read_dir("../../diamond-types/paper_benchmark_data/").unwrap() {
//     //     let entry = entry.unwrap();
//     //     let path = entry.path();
//     //     if path.is_file() && path.extension().and_then(OsStr::to_str) == Some("json") {
//     //         println!("Ermagherd {:?}", path);
//     //     }
//     // }
// }

#[cfg(feature = "memusage")]
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
struct MemUsage {
    steady_state: usize,
    peak: usize,
}


// Run with:
// $ cargo run --release --features memusage
#[cfg(feature = "memusage")]
fn measure_memory() {
    let filename = "../../results/ot_memusage.json";

    let mut usage = std::fs::read(filename).and_then(|old_data| {
        serde_json::from_slice(&old_data).map_err(std::io::Error::from)
    }).unwrap_or_else(|err| {
        eprintln!("Warning: Could not read old data from {filename}: {:?}", err);
        HashMap::new()
    });

    // dbg!(&usage);

    // for name in ["S1", "S2", "S3", "C1", "C2", "A1"] {
    // for name in ["A2"] {
    for name in ["S1", "S2", "S3", "C1", "C2", "A1", "A2"] {
        print!("{name}...");
        std::io::stdout().flush().unwrap();

        let (peak, steady_state, _) = measure_memusage(|| {
            let test_data = load_data(name);
            let result = test_data.doc_at_version(test_data.graph.frontier.0.as_slice());
            let r_str = result.to_string();

            // To maximally reduce the impact of a fragmented jumprope, I'll copy it into a new
            // rope. I could probably call clone(), but I don't trust it not to be clever somehow.
            let result = JumpRope::from(&r_str);

            if test_data.end_content != r_str {
                eprintln!("WARNING: {name} does not match expected document content")
            }

            result
        });

        println!(" peak memory: {peak} / steady state {steady_state}");
        usage.insert(name.to_string(), MemUsage { peak, steady_state });
    }

    let json_out = serde_json::to_vec_pretty(&usage).unwrap();
    std::fs::write(filename, json_out).unwrap();
    println!("JSON written to {filename}");
}

const DATASETS: &[&str] = &["S1", "S2", "S3", "C1", "C2", "A1", "A2"];

fn main() {
    #[cfg(feature = "memusage")]
    measure_memory();

    #[cfg(feature = "bench")]
    {
        let mut c = Criterion::default()
            .configure_from_args();

        // A2 takes 30 minutes to run. To benchmark A2, run this:
        // $ ./bench.sh --warm-up-time=0.001 --sample-size=10 A2

        // for name in ["clownschool", "friendsforever", "node_nodecc", "git-makefile"] {
        // for name in ["A2"] {
        // for name in ["S1", "S2", "S3", "C1", "C2", "A1"] {
        for &name in DATASETS {
            let mut group = c.benchmark_group("ot");
            let test_data = load_data(name);

            // group.throughput(Throughput::Elements(test_data.len() as u64));
            // group.throughput(Throughput::Elements(test_data.len_keystrokes() as u64));

            // A2 takes 30 minutes to run. This is the shortest we can make the test - but it still
            // takes about 5 hours to run.
            if name == "A2" {
                group.warm_up_time(Duration::from_millis(1));
                group.sample_size(10);
            }

            group.bench_function(name, |b| {
                b.iter(|| {
                    let result = test_data.doc_at_version(test_data.graph.frontier.0.as_slice());
                    let s = result.to_string();
                    black_box(s);
                })
            });

            group.finish();
        }

        c.final_summary();
    }
}