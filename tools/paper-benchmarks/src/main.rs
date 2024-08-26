#![allow(unused)]

use std::collections::BTreeMap;
use std::hint::black_box;
use std::path::PathBuf;
use argh::FromArgs;

use automerge::{AutoCommit, ReadDoc};
use automerge::transaction::Transactable;
use crdt_testdata::{load_testing_data, TestData};
#[cfg(feature = "bench")]
use criterion::Criterion;
use diamond_types::list::ListOpLog;
use serde::Serialize;
use trace_alloc::measure_memusage;
use yrs::{GetString, Text, Transact};
use yrs::updates::decoder::Decode;

#[cfg(feature = "bench")]
use crate::convert1::bench_automerge_remote;
#[cfg(feature = "bench")]
use crate::convert1::bench_yrs_remote;

mod benchmarks;
mod ff_bench;
mod convert1;

const DATASETS: &[&str] = &["S1", "S2", "S3", "C1", "C2", "A1", "A2"];
// const DATASETS: &[&str] = &[];

#[cfg(feature = "memusage")]
#[derive(Debug, Clone, Copy, Serialize)]
struct MemUsage {
    steady_state: usize,
    peak: usize,
}

fn stem() -> &'static str {
    if PathBuf::from("datasets").exists() { "." } else { "../.." }
}

pub fn am_filename_for(trace: &str) -> String {
    format!("{}/datasets/{trace}.am", stem())
}

pub fn yjs_filename_for(trace: &str) -> String {
    format!("{}/datasets/{trace}.yjs", stem())
}

// $ cargo run --features memusage --release
#[cfg(feature = "memusage")]
fn measure_memory<T>(prefix: &'static str, mut filename_for: impl FnMut(&str) -> String, mut run: impl FnMut(&[u8]) -> T) {
    let mut usage = BTreeMap::new();

    for &name in DATASETS {
        print!("{prefix}: {name}...");
        let filename = filename_for(name);
        let bytes = std::fs::read(&filename).unwrap();

        // The steady state is a jumprope object containing the document content.
        let (peak, steady_state, result) = measure_memusage(|| {
            // let doc = AutoCommit::load(&bytes).unwrap();
            // // black_box(doc);
            // let (_, text_id) = doc.get(automerge::ROOT, "text").unwrap().unwrap();
            // doc

            run(&bytes)
        });
        black_box(result);

        println!(" peak memory: {peak} / steady state {steady_state}");
        usage.insert(name.to_string(), MemUsage { peak, steady_state });
    }

    let json_out = serde_json::to_vec_pretty(&usage).unwrap();
    let filename = format!("{}/results/{}_memusage.json", stem(), prefix);
    std::fs::write(&filename, json_out).unwrap();
    println!("JSON written to {filename}");
}

fn bench_main() {
    // print_xf_sizes("friendsforever", 100);
    // print_xf_sizes("clownschool", 100);
    // print_xf_sizes("node_nodecc", 200);
    // print_xf_sizes("git-makefile", 200);
//
//     // benchmarks::print_filesize();
//     // if cfg!(feature = "memusage") {
//     //     benchmarks::print_memusage();
//     // }


    #[cfg(feature = "memusage")]
    {
        let cfg: Cfg = argh::from_env();

        if !cfg.automerge && !cfg.yjs {
            eprintln!("Missing argument: Specify -y for yjs memusage tracking and -a for automerge");
        }

        if cfg.automerge {
            measure_memory("automerge", am_filename_for, |bytes| {
                let doc = AutoCommit::load(&bytes).unwrap();
                let (_, text_id) = doc.get(automerge::ROOT, "text").unwrap().unwrap();
                doc
            });
        }

        if cfg.yjs {
            measure_memory("yrs", yjs_filename_for, |bytes| {
                let mut doc = yrs::Doc::new();
                let update = yrs::Update::decode_v2(&bytes).unwrap();
                {
                    let mut txn = doc.transact_mut();
                    txn.apply_update(update);
                    txn.commit();
                }

                // let text_ref = doc.get_or_insert_text("text");
                doc
            });
        }
    }

    // Benchmarks are selected using criterion's own args parser.
    #[cfg(feature = "bench")] {
        let mut c = Criterion::default()
            .configure_from_args();

        // bench_cola_remote(&mut c);
        bench_automerge_remote(&mut c);

        bench_yrs_remote(&mut c);
        // bench_ff(&mut c);

        // benchmarks::local_benchmarks(&mut c);

        c.final_summary();

        // convert_main();
    }
}

pub fn linear_testing_data(name: &str) -> TestData {
    let filename = format!("../../editing-traces/sequential_traces/{}.json.gz", name);
    load_testing_data(&filename)
}


/// Convert json editing traces to automerge and yjs
#[derive(Debug, FromArgs)]
struct Cfg {
    /// convert to yjs
    #[argh(switch, short='y')]
    yjs: bool,
    /// convert to automerge
    #[argh(switch, short='a')]
    automerge: bool,

    // /// input filename
    // #[argh(positional)]
    // input: PathBuf,
}


fn main() {
    // convert_main()
    bench_main()
    // get_cola_stats()
    //
    // #[cfg(feature = "memusage")]
    // convert1::get_cola_memusage();
}