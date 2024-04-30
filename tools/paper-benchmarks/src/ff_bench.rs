use crdt_testdata::TestPatch;
#[cfg(feature = "bench")]
use criterion::{BenchmarkGroup, BenchmarkId, Criterion};
#[cfg(feature = "bench")]
use criterion::measurement::WallTime;
use diamond_types::list::ListOpLog;
use crate::linear_testing_data;

pub const LINEAR_DATASETS: &[&str] = &["automerge-paper", "seph-blog1", "egwalker"];

const COMPLEX_DATASETS: &[&str] = &["node_nodecc", "git-makefile", "friendsforever", "clownschool"];

fn oplog_from_linear(name: &str) -> ListOpLog {
    let testdata = linear_testing_data(name);
    let mut doc = ListOpLog::new();
    let agent = doc.get_or_create_agent_id("test");
    for (_i, txn) in testdata.txns.iter().enumerate() {
        for TestPatch(pos, del_span, ins_content) in &txn.patches {
            if *del_span > 0 {
                doc.add_delete_without_content(agent, *pos..*pos + *del_span);
            }

            if !ins_content.is_empty() {
                doc.add_insert(agent, *pos, ins_content.as_str());
            }
        }
    }

    doc
}

#[cfg(feature = "bench")]
fn ff_bench(name: &str, c: &mut Criterion, oplog: &ListOpLog) {
    let mut group = c.benchmark_group(format!("dt"));
    // let mut group = c.benchmark_group(format!("ff/{name}"));


    group.bench_function(BenchmarkId::new("ff_on", name), |b| {
        b.iter(|| {
            oplog.iter_xf_operations().for_each(drop);
        })
    });

    group.bench_function(BenchmarkId::new("ff_off", name), |b| {
        b.iter(|| {
            oplog.dbg_iter_xf_operations_no_ff().for_each(drop);
        })
    });
    group.finish();

}

#[cfg(feature = "bench")]
pub fn bench_ff(c: &mut Criterion) {
    for name in LINEAR_DATASETS {
        let oplog = oplog_from_linear(name);
        ff_bench(name, c, &oplog);
    }

    for name in COMPLEX_DATASETS {
        let data = std::fs::read(format!("benchmark_data/{name}.dt")).unwrap();
        let oplog = ListOpLog::load_from(&data).unwrap();
        ff_bench(name, c, &oplog);
    }
}