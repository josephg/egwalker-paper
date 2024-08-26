#![allow(unused_imports)]

use argh::FromArgs;
use std::collections::{BinaryHeap, HashMap};
use std::error::Error;
use std::ffi::{OsStr, OsString};
use std::fs::File;
use std::io::BufReader;
use std::ops::Range;
use std::path::{Path, PathBuf};
use automerge::{ActorId, AutoCommit, Automerge, ObjType, ReadDoc};
use automerge::transaction::Transactable;
use criterion::{BenchmarkId, black_box, Criterion};
use diamond_types_crdt::list::ListCRDT;
use rand::Rng;
use rand::rngs::SmallRng;
use serde::{Deserialize, Serialize};
use smallvec::SmallVec;
use smartstring::alias::String as SmartString;
use yrs::{GetString, OffsetKind, Options, ReadTxn, StateVector, Text, TextRef, Transact, Update, Uuid};
use yrs::block::ClientID;
use yrs::updates::decoder::Decode;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EditHistory {
    num_agents: usize,
    end_content: String,
    txns: Vec<HistoryEntry>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SimpleTextOp(usize, usize, SmartString); // pos, del_len, ins_content.

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryEntry {
    parents: SmallVec<[usize; 2]>,
    num_children: usize,
    agent: usize,
    // op: TextOperation,
    patches: SmallVec<[SimpleTextOp; 2]>,
}


fn check_history(hist: &EditHistory) {
    // Each entry in the history must come causally after all other entries with the same agent.
    // Let's check thats actually true!

    let mut last_idx_for_agent = vec![usize::MAX; hist.num_agents];
    for (i, e) in hist.txns.iter().enumerate() {
        let agent = e.agent;
        let prev = last_idx_for_agent[agent];

        if prev != usize::MAX {
            // Check that prev comes causally before i. The first item with the same agent that
            // we run into in the BFS expansion must be prev.
            let mut queue = BinaryHeap::new();
            for parent in e.parents.iter() {
                queue.push(*parent);
            }

            while let Some(p_i) = queue.pop() {
                let p_e = &hist.txns[p_i];

                while let Some(peek_i) = queue.peek() { // Handle graph merging.
                    if *peek_i != p_i { break; }
                    queue.pop();
                }

                if p_e.agent == agent {
                    assert_eq!(p_i, prev, "Nonlinear edits from agent {agent}: {i} should come after {prev} but instead we found {p_i}");
                    break;
                }

                for parent in p_e.parents.iter() {
                    queue.push(*parent);
                }
            }

        }

        last_idx_for_agent[agent] = i;
    }
}


trait TextCRDT: Clone {
    fn new() -> Self;

    fn splice(&mut self, range: Range<usize>, ins_content: &str);

    fn merge_from(&mut self, other: &mut Self);

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

    fn merge_from(&mut self, other: &mut Self) {
        self.0.merge(&mut other.0).unwrap();
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

    fn merge_from(&mut self, other: &mut Self) {
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

// fn random_str(len: usize) -> String {
//     let mut str = String::new();
//     let alphabet: Vec<char> = "abcdefghijklmnop ".chars().collect();
//     for _ in 0..len {
//         str.push(alphabet[rand::thread_rng().gen_range(0..alphabet.len())]);
//     }
//     str
// }


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

    fn merge_from(&mut self, other: &mut Self) {
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

fn load_history<P: AsRef<Path>>(filename: P) -> EditHistory {
    let file = BufReader::new(File::open(filename).unwrap());
    serde_json::from_reader(file).unwrap()
}

fn process<C: TextCRDT>(history: &EditHistory) -> C {
    check_history(history);
    let doc = C::new();

    // There should be exactly one entry with no parents.
    let num_roots = history.txns.iter().filter(|e| e.parents.is_empty()).count();
    // assert_eq!(num_roots, 1);

    // The last item should be the output.
    let num_final = history.txns.iter().filter(|e| e.num_children == 0).count();
    assert_eq!(num_final, 1);

    let mut doc_at_idx: HashMap<usize, (C, usize)> = HashMap::new();
    doc_at_idx.insert(usize::MAX, (doc, num_roots));

    fn take_doc<C: TextCRDT>(doc_at_idx: &mut HashMap<usize, (C, usize)>, agent: Option<usize>, idx: usize) -> C {
        let (parent_doc, retains) = doc_at_idx.get_mut(&idx).unwrap();
        let mut doc = if *retains == 1 {
            // We'll just take the document.
            doc_at_idx.remove(&idx).unwrap().0
        } else {
            // Fork it and take the fork.
            *retains -= 1;
            parent_doc.fork(agent.unwrap_or(0))
        };

        if let Some(agent) = agent {
            doc.set_agent(agent);
        }
        doc
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

        let mut doc = take_doc(&mut doc_at_idx, Some(entry.agent), first_p);

        // If there's any more parents, merge them together.
        for p in rest_p {
            let mut doc2 = take_doc(&mut doc_at_idx, None, *p);
            doc.merge_from(&mut doc2);
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
            println!();
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


fn gen_main() -> Result<(), Box<dyn Error>> {

    // doc.splice_text(id, 0, 0, "hi there")?;
    // dbg!(&doc.get_heads());

    // let filename = "example_trace.json";
    // let filename = "friendsforever.json";
    let name = "clownschool";
    // let filename = "git_makefile.json";

    let history = load_history(&format!("{name}.json"));
    // dbg!(data);

    let mut doc = AutoCommit::new();
    let text_id = doc.put_object(automerge::ROOT, "text", ObjType::Text)?;


    // There should be exactly one entry with no parents.
    let num_roots = history.txns.iter().filter(|e| e.parents.is_empty()).count();
    // assert_eq!(num_roots, 1);

    // The last item should be the output.
    let num_final = history.txns.iter().filter(|e| e.num_children == 0).count();
    assert_eq!(num_final, 1);

    let mut doc_at_idx: HashMap<usize, (AutoCommit, usize)> = HashMap::new();
    doc_at_idx.insert(usize::MAX, (doc, num_roots));

    fn take_doc(doc_at_idx: &mut HashMap<usize, (AutoCommit, usize)>, idx: usize) -> AutoCommit {
        let (parent_doc, retains) = doc_at_idx.get_mut(&idx).unwrap();
        if *retains == 1 {
            // We'll just take the document.
            doc_at_idx.remove(&idx).unwrap().0
        } else {
            // Fork it and take the fork.
            *retains -= 1;
            parent_doc.fork()
        }
    }

    // doc_at_idx.insert(usize::MAX)

    // let mut root = Some(doc);
    for (idx, entry) in history.txns.iter().enumerate() {
        // First we need to get the doc we're editing.
        let (&first_p, rest_p) = entry.parents.split_first().unwrap_or((&usize::MAX, &[]));

        let mut doc = take_doc(&mut doc_at_idx, first_p);

        // If there's any more parents, merge them together.
        for p in rest_p {
            let mut doc2 = take_doc(&mut doc_at_idx, *p);
            doc.merge(&mut doc2).unwrap();
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
            doc.splice_text(text_id.clone(), op.0, op.1 as isize, &op.2).unwrap();
        }

        doc.commit();

        // And deposit the result back into doc_at_idx.
        if entry.num_children > 0 {
            doc_at_idx.insert(idx, (doc, entry.num_children));
        } else {
            println!("done!");
            let result = doc.text(text_id.clone()).unwrap();
            // println!("result: '{result}'");
            let saved = doc.save();
            println!("automerge document saves to {} bytes", saved.len());

            let out_filename = format!("{name}.am");
            std::fs::write(&out_filename, saved).unwrap();
            println!("Saved to {out_filename}");

            assert_eq!(result, history.end_content);
        }
    }

    Ok(())
}

// const DATASETS: &[&str] = &["automerge-paper", "seph-blog1", "clownschool", "friendsforever"];
// // const DATASETS: &[&str] = &["automerge-paper", "seph-blog1"];
//
// fn bench_process(c: &mut Criterion) {
//
//     for &name in DATASETS {
//
//         let mut group = c.benchmark_group("automerge");
//
//         // let name = "friendsforever";
//         let filename = format!("{name}.am");
//         let bytes = std::fs::read(&filename).unwrap();
//
//         group.bench_function(BenchmarkId::new( "remote", name), |b| {
//             b.iter(|| {
//                 let doc = AutoCommit::load(&bytes).unwrap();
//                 // black_box(doc);
//                 let (_, text_id) = doc.get(automerge::ROOT, "text").unwrap().unwrap();
//                 let result = doc.text(text_id).unwrap();
//                 black_box(result);
//             })
//         });
//     }
// }
//
// fn bench_main() {
//     // benches();
//     let mut c = Criterion::default()
//         .configure_from_args();
//
//     bench_process(&mut c);
//     c.final_summary();
// }

fn run_automerge(filename: &Path) {
    println!("Converting {} to automerge", filename.to_string_lossy());
    // let history = load_history(&format!("{filename}.json"));
    let history = load_history(filename);
    let (mut doc, text_id) = process::<AutomergeCRDT>(&history);

    // println!("done!");
    let result = doc.text(text_id.clone()).unwrap();
    black_box(result);
    // println!("result: '{result}'");
    let saved = doc.save();
    println!("automerge document saves to {} bytes", saved.len());

    // let out_filename = format!("{filename}.am");
    let out_filename = filename.with_extension("am");
    std::fs::write(&out_filename, saved).unwrap();
    println!("Saved to {}", out_filename.to_string_lossy());

    let saved_nocompress = doc.save_nocompress();
    println!("automerge uncompressed document size to {} bytes", saved_nocompress.len());

    // This is horrible.
    let mut out_filename = filename.to_path_buf();
    out_filename.set_extension("");
    let mut out_filename: OsString = out_filename.into();
    out_filename.push("-uncompressed");
    let mut out_filename: PathBuf = out_filename.into();
    out_filename.set_extension("am");
    // let out_filename = format!("{filename}-uncompressed.am");
    std::fs::write(&out_filename, saved_nocompress).unwrap();
    println!("Saved uncompressed data to {}", out_filename.to_string_lossy());

    // assert_eq!(result, history.end_content);
}

#[allow(unused)]
fn run_dt(filename: &Path) {
    // let history = load_history(&format!("{filename}.json"));
    let history = load_history(filename);
    let (doc, _) = process::<DTCRDT>(&history);

    assert_eq!(doc.to_string(), history.end_content);
}

fn run_yrs(filename: &Path) {
    println!("Converting {} to Yrs", filename.to_string_lossy());
    let history = load_history(filename);
    let (doc, text_ref) = process::<YrsCRDT>(&history);

    let content = text_ref.get_string(&doc.transact());
    if content != history.end_content {
        std::fs::write("a", &history.end_content).unwrap();
        std::fs::write("b", &content).unwrap();
        eprintln!("WARNING: Yjs output does not match expected output! Written to a / b");
        // panic!("Does not match! Written to a / b");
    }
    // assert_eq!(content, history.end_content, "content does not match");

    // let out_filename = format!("{filename}.yjs");
    let out_filename = filename.with_extension("yjs");
    std::fs::write(&out_filename, doc.transact().encode_state_as_update_v2(&StateVector::default())).unwrap();
    println!("Saved to {}", out_filename.to_string_lossy());
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

    /// input filename
    #[argh(positional)]
    input: PathBuf,
}

fn main() {
    // run_yrs("automerge-paper");
    // run_yrs("seph-blog1");
    // run_yrs("friendsforever");
    // run_yrs("clownschool");
    // run_yrs("node_nodecc");

    // "git-makefilex3",
    // for file in &["automerge-paperx3", "seph-blog1x3", "node_nodeccx1", "friendsforeverx25", "clownschoolx25", "egwalkerx1"] {


    // for file in &["S1", "S2", "S3", "C1", "C2", "A1", "A2"] {
    //     println!("\n\n----\n{file}");
    //     run_automerge(&format!("../../datasets/{}", file));
    //     run_yrs(&format!("../../datasets/{}", file));
    // }

    let cfg: Cfg = argh::from_env();
    if cfg.yjs {
        run_yrs(&cfg.input);
    }
    if cfg.automerge {
        run_automerge(&cfg.input);
    }

    // run_automerge("automerge-paper");
    // run_automerge("seph-blog1");
    // run_automerge("friendsforever");
    // run_automerge("clownschool");
    // run_automerge("node_nodecc");

    // run_automerge("friendsforever");
    // run_dt("friendsforever");
    // gen_main().unwrap();

    // To benchmark, uncomment this line and run with:
    // cargo run --release -- --bench
    // bench_main();
}