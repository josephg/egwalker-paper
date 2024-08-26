use std::hint::black_box;
use std::ops::Range;
use diamond_types_crdt::list::ListCRDT as DTCRDT;
#[cfg(feature = "bench")]
use criterion::{Bencher, BenchmarkId, Criterion, Throughput};
use diamond_types::list::ListOpLog;
use diamond_types::list::encoding::ENCODE_FULL;
use diamond_types::AgentId;
use automerge::{AutoCommit, Automerge, ObjType};
use crdt_testdata::{TestData, TestPatch};
use trace_alloc::get_thread_memory_usage;
use yrs::{Text, TextRef, Transact};
use automerge::transaction::Transactable;

// pub const LINEAR_DATASETS: &[&str] = &["automerge-paper", "seph-blog1", "friendsforever_flat", "clownschool_flat"];
pub const LINEAR_DATASETS: &[&str] = &["automerge-paper", "seph-blog1", "friendsforever_flat", "clownschool_flat", "egwalker"];
// pub const LINEAR_DATASETS: &[&str] = &["automerge-paper", "rustcode", "sveltecomponent", "seph-blog1", "friendsforever_flat", "clownschool_flat"];


pub trait UpstreamTextCRDT {
    fn new() -> Self;

    fn name() -> &'static str;

    fn local_del(&mut self, range: Range<usize>);

    fn local_ins(&mut self, pos: usize, content: &str);

    fn get_filesize(&self) -> usize {
        panic!("get_filesize not implemented for type");
    }
    // fn len(&self) -> usize;
}

pub trait DownstreamCRDT {
    type Data;

    fn get_data(&self) -> Self::Data;
    // fn get_doc(&self) -> &JumpRopeBuf;
    fn process(data: &Self::Data);
}

impl UpstreamTextCRDT for (DTCRDT, u16) {
    fn new() -> Self {
        let mut doc = DTCRDT::new();
        // let mut doc = DTCRDT::new_pure_oplog();
        let agent = doc.get_or_create_agent_id("test");

        (doc, agent)
    }

    fn name() -> &'static str {
        "dt-crdt"
    }

    fn local_del(&mut self, range: Range<usize>) {
        self.0.local_delete(self.1, range.start, range.len());
    }

    fn local_ins(&mut self, pos: usize, content: &str) {
        self.0.local_insert(self.1, pos, content);
    }

    fn get_filesize(&self) -> usize {
        self.0.encode_small(false).len()
    }
}

impl DownstreamCRDT for (DTCRDT, u16) {
    type Data = Vec<diamond_types_crdt::list::external_txn::RemoteTxn>;

    fn get_data(&self) -> Self::Data {
        self.0.get_all_txns()
    }

    fn process(data: &Self::Data) {
        let mut doc = DTCRDT::new();
        debug_assert!(doc.has_content());
        for txn in data.iter() {
            doc.apply_remote_txn(&txn);
        }
        black_box(doc);
        // assert_eq!(doc.len(), src_doc.len());
    }
}

type DT = (ListOpLog, AgentId);

impl UpstreamTextCRDT for DT {
    fn new() -> Self {
        let mut doc = ListOpLog::new();
        let agent = doc.get_or_create_agent_id("test");
        (doc, agent)
    }

    fn name() -> &'static str {
        "dt"
    }

    fn local_del(&mut self, range: Range<usize>) {
        self.0.add_delete_without_content(self.1, range);
    }

    fn local_ins(&mut self, pos: usize, content: &str) {
        self.0.add_insert(self.1, pos, content);
    }

    fn get_filesize(&self) -> usize {
        self.0.encode(&ENCODE_FULL).len()
    }
}

impl DownstreamCRDT for DT {
    type Data = ListOpLog;

    fn get_data(&self) -> Self::Data {
        self.0.clone()
    }

    fn process(data: &Self::Data) {
        black_box(data.checkout_tip().content());
    }
}

type AutomergeCRDT = (AutoCommit, automerge::ObjId);

impl UpstreamTextCRDT for AutomergeCRDT {
    fn new() -> Self {
        let mut doc = AutoCommit::new();
        let id = doc.put_object(automerge::ROOT, "text", ObjType::Text).unwrap();
        (doc, id)
    }

    fn name() -> &'static str {
        "automerge"
    }

    fn local_del(&mut self, range: Range<usize>) {
        self.0.splice_text(&self.1, range.start, range.len() as _, "").unwrap();
    }

    fn local_ins(&mut self, pos: usize, content: &str) {
        self.0.splice_text(&self.1, pos, 0, content).unwrap();
    }

    fn get_filesize(&self) -> usize {
        self.0.clone().save().len()
    }
}

impl DownstreamCRDT for AutomergeCRDT {
    type Data = (Vec<u8>, automerge::ObjId);

    fn get_data(&self) -> Self::Data {
        (self.0.clone().save(), self.1.clone())
    }

    fn process(data: &Self::Data) {
        let doc = AutoCommit::load(&data.0).unwrap();
        black_box(doc);

        // let text = doc.text(&data.1).unwrap();
        // black_box(text);
    }
}

type AutomergeCRDT2 = (Automerge, automerge::ObjId);

impl UpstreamTextCRDT for AutomergeCRDT2 {
    fn new() -> Self {
        let mut doc = Automerge::new();
        let id = doc.transact(|txn| {
            txn.put_object(automerge::ROOT, "text", ObjType::Text)
        }).unwrap().result;
        (doc, id)
    }

    fn name() -> &'static str {
        "automerge-txns"
    }

    fn local_del(&mut self, range: Range<usize>) {
        let id = self.0.transact(|txn| {
            txn.splice_text(&self.1, range.start, range.len() as _, "")
        }).unwrap();
    }

    fn local_ins(&mut self, pos: usize, content: &str) {
        let id = self.0.transact(|txn| {
            txn.splice_text(&self.1, pos, 0, content)
        }).unwrap();
    }

    fn get_filesize(&self) -> usize {
        self.0.save().len()
    }
}

impl DownstreamCRDT for AutomergeCRDT2 {
    type Data = (Vec<u8>, automerge::ObjId);

    fn get_data(&self) -> Self::Data {
        (self.0.save(), self.1.clone())
    }

    fn process(data: &Self::Data) {
        let doc = Automerge::load(&data.0).unwrap();
        black_box(doc);

        // let text = doc.text(&data.1).unwrap();
        // black_box(text);
    }
}

type YrsCRDT = (yrs::Doc, TextRef);
impl UpstreamTextCRDT for (yrs::Doc, TextRef) {
    fn new() -> Self {
        let doc = yrs::Doc::new();
        let r = doc.get_or_insert_text("text");
        (doc, r)
    }

    fn name() -> &'static str {
        "yrs"
    }

    fn local_del(&mut self, range: Range<usize>) {
        let mut txn = self.0.transact_mut();
        self.1.remove_range(&mut txn, range.start as u32, range.len() as u32);
        txn.commit();
    }

    fn local_ins(&mut self, pos: usize, content: &str) {
        let mut txn = self.0.transact_mut();
        self.1.insert(&mut txn, pos as u32, content);
        txn.commit();
    }
}

// impl UpstreamTextCRDT for cola::Replica {
//     fn new() -> Self {
//         cola::Replica::new(1, 0)
//     }
//
//     fn name() -> &'static str {
//         "cola"
//     }
//
//     fn local_del(&mut self, range: Range<usize>) {
//         let _ = self.deleted(range);
//     }
//
//     fn local_ins(&mut self, pos: usize, content: &str) {
//         // let _ = self.inserted(pos, content.chars().count());
//         let _ = self.inserted(pos, content.len()); // Only correct for ASCII traces.
//     }
// }
//
// impl DownstreamCRDT for cola::Replica {
//     type Data = cola::EncodedReplica;
//
//     fn get_data(&self) -> Self::Data {
//         self.encode()
//     }
//
//     fn process(data: &Self::Data) {
//         let local = cola::Replica::decode(2, data).unwrap();
//         black_box(local);
//     }
// }

// impl UpstreamTextCRDT for cola_nocursor::Replica {
//     fn new() -> Self {
//         cola_nocursor::Replica::new(1, 0)
//     }
//
//     fn name() -> &'static str {
//         "cola-nocursor"
//     }
//
//     fn local_del(&mut self, range: Range<usize>) {
//         let _ = self.deleted(range);
//     }
//
//     fn local_ins(&mut self, pos: usize, content: &str) {
//         // let _ = self.inserted(pos, content.chars().count());
//         let _ = self.inserted(pos, content.len()); // Only correct for ASCII traces.
//     }
// }

fn apply_local_patches<C: UpstreamTextCRDT>(mut crdt: &mut C, data: &TestData) {
    for (_i, txn) in data.txns.iter().enumerate() {
        for TestPatch(pos, del_span, ins_content) in &txn.patches {
            if *del_span > 0 {
                crdt.local_del(*pos..*pos + *del_span);
                // doc.delete(id, *pos .. *pos + *del_span);
            }

            if !ins_content.is_empty() {
                crdt.local_ins(*pos, ins_content.as_str());
                // doc.insert(id, *pos, ins_content);
            }
        }
    }
}

#[cfg(feature = "bench")]
fn bench_local<C: UpstreamTextCRDT>(b: &mut Bencher, data: &TestData) {
    let mut crdt = C::new();
    b.iter(|| {
        apply_local_patches(&mut crdt, data);
    });
    black_box(crdt);
}

#[cfg(feature = "bench")]
fn bench_remote<C: UpstreamTextCRDT + DownstreamCRDT>(b: &mut Bencher, data: &TestData) {
    let mut crdt = C::new();
    apply_local_patches(&mut crdt, data);
    let data = crdt.get_data();
    b.iter(|| {
        C::process(&data);
    });
}

fn get_filesize<C: UpstreamTextCRDT>(data: &TestData) -> usize {
    let mut crdt = C::new();
    apply_local_patches(&mut crdt, data);
    crdt.get_filesize()
}

#[cfg(feature = "bench")]
pub fn local_benchmarks(c: &mut Criterion) {
    fn benchmark_algorithm<C: UpstreamTextCRDT>(c: &mut Criterion) {
        let mut group = c.benchmark_group(C::name());
        for name in LINEAR_DATASETS {
            let test_data = crate::linear_testing_data(name); // Could cache these but eh.
            group.bench_function(BenchmarkId::new("local", name), |b| {
                bench_local::<C>(b, &test_data);
            });
        }
        group.finish();
    }

    benchmark_algorithm::<(DTCRDT, u16)>(c);
    benchmark_algorithm::<DT>(c);
    benchmark_algorithm::<AutomergeCRDT>(c);
    // benchmark_algorithm::<AutomergeCRDT2>(c);
    // group.bench_with_input("automerge2",&test_data, bench_crdt::<AutomergeCRDT2>);

    // benchmark_algorithm::<cola::Replica>(c);
    // benchmark_algorithm::<cola_nocursor::Replica>(c);

    // benchmark_algorithm::<YrsCRDT>(c); // This is super slow.

    // for name in LINEAR_DATASETS {
    //     let mut local = c.benchmark_group(format!("local/{name}"));
    //     let test_data = crate::linear_testing_data(name);
    //     assert_eq!(test_data.start_content.len(), 0);
    //
    //     local.throughput(Throughput::Elements(test_data.len() as u64));
    //
    //     local.bench_with_input("dt-crdt", &test_data, bench_local::<(DTCRDT, u16)>);
    //     local.bench_with_input("dt", &test_data, bench_local::<DT>);
    //     local.bench_with_input("automerge", &test_data, bench_local::<AutomergeCRDT>);
    //     // group.bench_with_input("automerge2",&test_data, bench_crdt::<AutomergeCRDT2>);
    //     local.bench_with_input("yrs", &test_data, bench_local::<YrsCRDT>);
    //     local.bench_with_input("cola", &test_data, bench_local::<cola::Replica>);
    //     local.bench_with_input("cola-nocursor", &test_data, bench_local::<cola_nocursor::Replica>);
    //
    //     local.finish();
    //
    //
    //     // let mut remote = c.benchmark_group(format!("remote/{name}"));
    //     // remote.bench_with_input("dt-crdt", &test_data, bench_remote::<(DTCRDT, u16)>);
    //     // remote.bench_with_input("dt", &test_data, bench_remote::<DT>);
    //     // remote.bench_with_input("automerge", &test_data, bench_remote::<AutomergeCRDT>);
    //     // remote.bench_with_input("cola", &test_data, bench_remote::<cola::Replica>);
    //     //
    //     // remote.finish();
    // }
}

// pub fn print_filesize() {
//     for name in LINEAR_DATASETS {
//         let test_data = crate::linear_testing_data(name);
//
//         println!("am size for {name}: {}", get_filesize::<AutomergeCRDT>(&test_data));
//         println!("am2 size for {name}: {}", get_filesize::<AutomergeCRDT2>(&test_data));
//         println!("dt size for {name}: {}", get_filesize::<DT>(&test_data));
//         println!("dt-crdt size for {name}: {}", get_filesize::<(DTCRDT, u16)>(&test_data));
//         println!();
//     }
// }
//
//
// fn get_memusage<C: UpstreamTextCRDT>(data: &TestData) -> isize {
//     let before_usage = get_thread_memory_usage();
//     let mut crdt = C::new();
//     apply_local_patches(&mut crdt, data);
//     let after_usage = get_thread_memory_usage();
//
//     // println!("Memory usage: {}", after_usage - before_usage);
//     after_usage - before_usage
// }
//
// pub fn print_memusage() {
//     for name in LINEAR_DATASETS {
//         let test_data = crate::linear_testing_data(name);
//
//         println!("am memory usage for {name}: {}", get_memusage::<AutomergeCRDT>(&test_data));
//         println!("am2 memory usage for {name}: {}", get_memusage::<AutomergeCRDT2>(&test_data));
//         println!("dt memory usage for {name}: {}", get_memusage::<DT>(&test_data));
//         println!("dt-crdt memory usage for {name}: {}", get_memusage::<(DTCRDT, u16)>(&test_data));
//         println!("cola memory usage for {name}: {}", get_memusage::<cola::Replica>(&test_data));
//         println!();
//         // get_memusage::<AutomergeCRDT>(&test_data);
//         // get_memusage::<DT>(&test_data);
//         // get_memusage::<(DTCRDT, u16)>(&test_data);
//     }
// }
