#![allow(unused_imports)]

use std::cell::RefCell;
use std::collections::HashMap;
use std::error::Error;
use std::fs::File;
use std::hint::black_box;
use std::io::BufReader;
use std::ops::Range;
use automerge::{ActorId, AutoCommit, Automerge, ObjType, ReadDoc};
use automerge::transaction::Transactable;
// use cola::Replica;
#[cfg(feature = "bench")]
use criterion::{BenchmarkId, Criterion};
use diamond_types_crdt::list::ListCRDT;
use jumprope::JumpRopeBuf;
use rand::Rng;
use rand::rngs::SmallRng;
use serde::Deserialize;
use smallvec::SmallVec;
use smartstring::alias::String as SmartString;
use yrs::{GetString, OffsetKind, Options, ReadTxn, StateVector, Text, TextRef, Transact, Update, Uuid};
use yrs::block::ClientID;
use yrs::updates::decoder::Decode;
use crate::{am_filename_for, yjs_filename_for};

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EditHistory {
    num_agents: usize,
    end_content: String,
    txns: Vec<HistoryEntry>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct SimpleTextOp(usize, usize, SmartString); // pos, del_len, ins_content.

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryEntry {
    parents: SmallVec<[usize; 2]>,
    num_children: usize,
    agent: usize,
    // op: TextOperation,
    patches: SmallVec<[SimpleTextOp; 2]>,
}


trait TextCRDT: Clone {
    fn new() -> Self;

    fn splice(&mut self, range: Range<usize>, ins_content: &str);

    fn merge_from(&mut self, other: &Self);

    fn commit(&mut self) {}
    fn fork(&mut self, actor_hint: usize) -> Self;

    fn set_agent(&mut self, actor: usize);

    // fn local_del(&mut self, range: Range<usize>);
    //
    // fn local_ins(&mut self, pos: usize, content: &str);
}

fn am_agent_for_agentid(agent: usize) -> ActorId {
    let bytes = agent.to_be_bytes();
    ActorId::from(bytes)
}

type AutomergeCRDT = (AutoCommit, automerge::ObjId);
impl TextCRDT for AutomergeCRDT {
    fn new() -> Self {
        let mut doc = AutoCommit::new();
        doc.set_actor(ActorId::from(&[0xff])); // We'll make the root object with a dummy "root" ActorId
        let id = doc.put_object(automerge::ROOT, "text", ObjType::Text).unwrap();
        (doc, id)
    }

    fn splice(&mut self, mut range: Range<usize>, ins_content: &str) {
        let len = self.0.text(&self.1).unwrap().chars().count();
        // if range.start > len {
        //     println!("Truncated {} -> {}", range.start, len);
        // }
        range.start = range.start.min(len);
        range.end = range.end.min(len);
        self.0.splice_text(&self.1, range.start, range.len() as _, ins_content).unwrap();
    }

    fn merge_from(&mut self, other: &Self) {
        // Calling clone() here makes automerge much slower. The other option is to take &mut self
        // - and that makes all the other code more awful.
        //
        // Conversion only happens once. Clone it is!
        self.0.merge(&mut other.0.clone()).unwrap();
    }

    fn commit(&mut self) {
        self.0.commit();
    }

    fn fork(&mut self, _agent_hint: usize) -> Self {
        (self.0.fork(), self.1.clone())
    }

    fn set_agent(&mut self, agent: usize) {
        self.0.set_actor(am_agent_for_agentid(agent));
    }
}


fn to_yjs_agent(agent: usize) -> ClientID {
    // Yjs's ClientID is a u64.
    agent as ClientID
}

fn yrs_opts(agent: Option<usize>) -> Options {
    let mut opts = Options::default();
    opts.client_id = to_yjs_agent(agent.unwrap_or(0xffff)); // Make it deterministic.
    opts.guid = Uuid::from("DET_PLACEHOLDER"); // This is a bit dirty, but seems fine?

    // This also isn't quite right. We're actually using unicode offsets, so this will corrupt
    // if any characters are outside the unicode BMP.
    opts.offset_kind = OffsetKind::Utf16;

    opts
}

type YrsCRDT = (yrs::Doc, TextRef);
impl TextCRDT for YrsCRDT {
    fn new() -> Self {
        let opts = yrs_opts(None);
        let doc = yrs::Doc::with_options(opts);
        let r = doc.get_or_insert_text("text");
        (doc, r)
    }

    fn splice(&mut self, mut range: Range<usize>, ins_content: &str) {
        let mut txn = self.0.transact_mut();

        let len = self.1.get_string(&txn).chars().count();
        if range.start > len { range.start = len; }
        if range.end > len { range.end = len; }

        if !range.is_empty() {
            self.1.remove_range(&mut txn, range.start as u32, range.len() as u32);
        }
        if !ins_content.is_empty() {
            let mut ok = true;
            for c in ins_content.chars() {
                if c.len_utf16() != 1 {
                    println!("Non-UTF16 safe character found '{}' - replacing with underscore", c);
                    ok = false;
                }
            }
            if ok {
                self.1.insert(&mut txn, range.start as u32, ins_content);
            } else {
                let replaced_content = ins_content.chars().map(|c| {
                    if c.len_utf16() == 1 { c }
                    else { '_' }
                }).collect::<String>();
                self.1.insert(&mut txn, range.start as u32, &replaced_content);
            }
        }
        // self.1.inser
        txn.commit();

    }

    fn merge_from(&mut self, other: &Self) {
        // let sv = self.0.transact().state_vector();
        // let update = other.0.transact().encode_state_as_update_v2(&StateVector::default());
        let sv = self.0.transact().state_vector();
        let update = other.0.transact().encode_state_as_update_v2(&sv);

        let mut txn = self.0.transact_mut();
        txn.apply_update(Update::decode_v2(&update).unwrap());
        txn.commit();
    }

    fn fork(&mut self, agent_hint: usize) -> Self {

        // Bleh I want to just call clone but then the client IDs match. And there's no way to
        // change the client ID once an object has been created.
        // let r = self.clone();
        // dbg!(self.0.client_id(), r.0.client_id());
        // r

        let update = self.0.transact().encode_state_as_update_v2(&StateVector::default());

        let opts = yrs_opts(Some(agent_hint));
        let doc2 = yrs::Doc::with_options(opts);
        doc2.transact_mut().apply_update(Update::decode_v2(&update).unwrap());
        let r = doc2.get_or_insert_text("text");

        (doc2, r)
    }

    fn set_agent(&mut self, agent: usize) {
        // Since there's no way to do this using the yjs API directly, I'll fork the document. Bleh.
        let client_id = to_yjs_agent(agent);
        if self.0.client_id() != client_id {
            let result = self.fork(agent);
            self.0 = result.0;
            self.1 = result.1;
        }
    }
}

fn random_str(len: usize) -> String {
    let mut str = String::new();
    let alphabet: Vec<char> = "abcdefghijklmnop ".chars().collect();
    for _ in 0..len {
        str.push(alphabet[rand::thread_rng().gen_range(0..alphabet.len())]);
    }
    str
}


type DTCRDT = (ListCRDT, u16);
impl TextCRDT for DTCRDT {
    fn new() -> Self {
        let mut doc = ListCRDT::new();
        let agent = doc.get_or_create_agent_id("test");
        (doc, agent)
    }

    fn splice(&mut self, range: Range<usize>, ins_content: &str) {
        if !range.is_empty() {
            self.0.local_delete(self.1, range.start, range.len());
        }
        if !ins_content.is_empty() {
            self.0.local_insert(self.1, range.start, ins_content);
        }
    }

    fn merge_from(&mut self, other: &Self) {
        other.0.replicate_into(&mut self.0);
    }

    fn fork(&mut self, actor_hint: usize) -> Self {
        let mut new_doc = self.0.clone();
        let agent = new_doc.get_or_create_agent_id(&format!("{:#010x}", actor_hint)); // 10 because the leading "0x" is counted.
        (new_doc, agent)
    }

    fn set_agent(&mut self, actor: usize) {
        self.1 = self.0.get_or_create_agent_id(&format!("{:#010x}", actor)); // 10 because the leading "0x" is counted.
    }
}

fn load_history(name: &str) -> EditHistory {
    let filename = format!("../../datasets/{name}.json");
    // dbg!(&filename);
    let file = BufReader::new(File::open(filename).unwrap());
    serde_json::from_reader(file).unwrap()
}

fn process<C: TextCRDT>(history: &EditHistory) -> C {
    // check_history(history);
    let doc = C::new();

    // There should be exactly one entry with no parents.
    let num_roots = history.txns.iter().filter(|e| e.parents.is_empty()).count();
    // assert_eq!(num_roots, 1);

    // The last item should be the output.
    let num_final = history.txns.iter().filter(|e| e.num_children == 0).count();
    assert_eq!(num_final, 1);

    let mut doc_at_idx: HashMap<usize, (C, usize)> = HashMap::new();
    doc_at_idx.insert(usize::MAX, (doc, num_roots));


    fn borrow_doc<C: TextCRDT>(doc_at_idx: &HashMap<usize, (C, usize)>, idx: usize) -> &C {
        &doc_at_idx.get(&idx).unwrap().0
    }

    fn dec_rc<C: TextCRDT>(doc_at_idx: &mut HashMap<usize, (C, usize)>, idx: usize) {
        let entry = doc_at_idx.get_mut(&idx).unwrap();
        entry.1 -= 1;
        if entry.1 == 0 {
            doc_at_idx.remove(&idx).unwrap();
        }
    }

    fn take_doc<C: TextCRDT>(doc_at_idx: &mut HashMap<usize, (C, usize)>, agent: usize, idx: usize) -> C {
        let (parent_doc, retains) = doc_at_idx.get_mut(&idx).unwrap();
        if *retains == 1 {
            // We'll just take the document.
            let mut doc = doc_at_idx.remove(&idx).unwrap().0;
            doc.set_agent(agent);
            doc
        } else {
            // Fork it and take the fork.
            assert!(*retains > 1);
            *retains -= 1;
            // parent_doc.clone()
            parent_doc.fork(agent)
        }
    }

    // doc_at_idx.insert(usize::MAX)

    // let mut root = Some(doc);
    let len = history.txns.len();
    // dbg!(len);
    let dot_every = (len / 30) + 1;

    for (idx, entry) in history.txns.iter().enumerate() {
        if idx % dot_every == 0 { eprint!("."); }

        // First we need to get the doc we're editing.
        let (&first_p, rest_p) = entry.parents.split_first().unwrap_or((&usize::MAX, &[]));

        let mut doc = take_doc(&mut doc_at_idx, entry.agent, first_p);

        // If there's any more parents, merge them together.
        for p in rest_p {
            let doc2 = borrow_doc(&doc_at_idx, *p);
            // let mut doc2 = take_doc(&mut doc_at_idx, None, *p);
            doc.merge_from(doc2);
            dec_rc(&mut doc_at_idx, *p);
        }

        // Gross - actor IDs are fixed 16 byte arrays.
        // let actor = ActorId::from()
        // let mut actor_bytes = [0u8; 16];
        // let copied_bytes = actor_bytes.len().min(entry.agent.len());
        // actor_bytes[..copied_bytes].copy_from_slice(&entry.agent.as_bytes()[..copied_bytes]);

        // This is necessary or we get duplicate actor/seq pairs. It should be possible to just keep
        // using the same actor with new sequence numbers for subsequent changes, but I don't think
        // the automerge API makes this possible.
        // actor_bytes[12..16].copy_from_slice(&(entry.id as u32).to_be_bytes());
        // let actor = ActorId::from(actor_bytes);
        // doc.set_actor(actor);


        // Ok, now modify the document.
        for op in &entry.patches {
            doc.splice(op.0 .. op.0 + op.1, &op.2);
            // doc.splice_text(text_id.clone(), op.0, op.1 as isize, &op.2).unwrap();
        }

        doc.commit();

        // And deposit the result back into doc_at_idx.
        if entry.num_children > 0 {
            doc_at_idx.insert(idx, (doc, entry.num_children));
        } else {
            // println!();
            return doc;
            // println!("done!");
            // let result = doc.text(text_id.clone()).unwrap();
            // // println!("result: '{result}'");
            // let saved = doc.save();
            // println!("automerge document saves to {} bytes", saved.len());
            //
            // let out_filename = format!("{filename}.am");
            // std::fs::write(&out_filename, saved).unwrap();
            // println!("Saved to {out_filename}");
            //
            // assert_eq!(result, history.end_content);
        }
    }

    // Ok(())
    unreachable!();
}

// const DATASETS: &[&str] = &["automerge-paperx4", "seph-blog1x3", "node_nodeccx1", "git-makefilex3", "friendsforeverx40", "clownschoolx40", "egwalkerx1"];
//const DATASETS: &[&str] = &["automerge-paperx3", "seph-blog1x3", "node_nodeccx1", "friendsforeverx25", "clownschoolx25", "egwalkerx1"];
const DATASETS: &[&str] = &["S1", "S2", "S3", "C1", "C2", "A1", "A2"];

// const DATASETS: &[&str] = &["automerge-paper", "seph-blog1", "clownschool", "friendsforever", "node_nodecc", "egwalker"];
// const DATASETS: &[&str] = &["automerge-paper", "seph-blog1"];

#[cfg(feature = "bench")]
pub fn bench_automerge_remote(c: &mut Criterion) {

    for &name in DATASETS {

        let mut group = c.benchmark_group("automerge");

        // let name = "friendsforever";
        let filename = am_filename_for(name);
        let bytes = std::fs::read(&filename);
        match bytes {
            Ok(bytes) => {
                group.bench_function(BenchmarkId::new("remote", name), |b| {
                    b.iter(|| {
                        let doc = AutoCommit::load(&bytes).unwrap();
                        // black_box(doc);
                        let (_, text_id) = doc.get(automerge::ROOT, "text").unwrap().unwrap();
                        let result = doc.text(text_id).unwrap();
                        black_box(result);
                    })
                });
            },
            Err(err) => {
                eprintln!("Error: Could not load data for test {:?}: {:?}", filename, err);
            }
        }
    }
}


#[cfg(feature = "bench")]
pub fn bench_yrs_remote(c: &mut Criterion) {

    for &name in DATASETS {
        let mut group = c.benchmark_group("yrs");

        // let name = "friendsforever";
        let filename = yjs_filename_for(name);
        let bytes = std::fs::read(&filename).unwrap();
        group.bench_function(BenchmarkId::new("remote", name), |b| {
            b.iter(|| {
                let mut doc = yrs::Doc::new();
                let update = yrs::Update::decode_v2(&bytes).unwrap();
                {
                    let mut txn = doc.transact_mut();
                    txn.apply_update(update);
                    txn.commit();
                }

                let text_ref = doc.get_or_insert_text("text");
                let text = text_ref.get_string(&doc.transact());

                black_box((doc, text));
            })
        });
    }
}


fn convert_automerge(filename: &str) {
    println!("Processing {filename}...");
    let history = load_history(filename);
    let (mut doc, text_id) = process::<AutomergeCRDT>(&history);

    println!("done!");
    let result = doc.text(text_id.clone()).unwrap();
    // println!("result: '{result}'");
    let saved = doc.save();
    println!("automerge document saves to {} bytes", saved.len());

    let out_filename = format!("{filename}.am");
    std::fs::write(&out_filename, saved).unwrap();
    println!("Saved to {out_filename}");


    let saved_nocompress = doc.save_nocompress();
    println!("automerge uncompressed document size to {} bytes", saved_nocompress.len());

    let out_filename = format!("{filename}-uncompressed.am");
    std::fs::write(&out_filename, saved_nocompress).unwrap();
    println!("Saved uncompressed data to {out_filename}");

    assert_eq!(result, history.end_content);
}

fn run_dt(filename: &str) {
    let history = load_history(filename);
    let (doc, _) = process::<DTCRDT>(&history);

    assert_eq!(doc.to_string(), history.end_content);
}

fn convert_yjs(filename: &str) {
    println!("Processing {filename}...");
    let history = load_history(filename);
    let (doc, text_ref) = process::<YrsCRDT>(&history);

    let content = text_ref.get_string(&doc.transact());
    if content != history.end_content {
        std::fs::write("a", &history.end_content).unwrap();
        std::fs::write("b", &content).unwrap();
        panic!("Does not match! Written to a / b");
    }
    assert_eq!(content, history.end_content, "content does not match");

    let out_filename = format!("{filename}.yjs");
    std::fs::write(&out_filename, doc.transact().encode_state_as_update_v2(&StateVector::default())).unwrap();
    println!("Saved to {out_filename}");
}

pub fn convert_main() {
    // convert_yjs("automerge-paper");
    // convert_yjs("seph-blog1");
    // convert_yjs("friendsforever");
    // convert_yjs("clownschool");
    // convert_yjs("egwalker");


    // convert_cola("S1");
    // convert_cola("S2");
    // convert_cola("S3");
    // convert_cola("C1");
    // convert_cola("C2");
    // convert_cola("A1");
    // convert_cola("A2");


    // run_automerge("automerge-paper");
    // run_automerge("seph-blog1");
    // run_automerge("friendsforever");
    // run_automerge("clownschool");
    // convert_automerge("egwalker");

    // convert_yjs("node_nodecc");
    // run_automerge("friendsforever");
    // run_dt("friendsforever");
    // gen_main().unwrap();

    // To benchmark, uncomment this line and run with:
    // cargo run --release -- --bench
    // bench_main();
}
