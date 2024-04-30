// //! This implementation of OT doesn't support TP2 - so it will have artificially better performance
// //! than a suitably comparable OT implementation.
//
// use std::iter::FromIterator;
// use smartstring::alias::{String as SmartString};
// use smallvec::{SmallVec, smallvec};
// use crate::OpSet;
//
// // mod editablestring;
// // use self::editablestring::EditableText;
//
// #[derive(Debug, PartialEq, Eq, Clone)]
// pub enum OpComponentTP2 {
//     Skip(usize),
//     Del(usize),
//
//     // I need to frequently get the string's unicode length, which in rust is a
//     // O(n) operation. I could store the length alongside the string, but the
//     // string is almost always short so ... its probably not a big deal either
//     // way.
//     Ins(SmartString),
//
//     InsTombstone(usize),
// }
//
// use self::OpComponentTP2::*;
//
// impl OpComponentTP2 {
//     pub fn ins_from<T>(s: T) -> OpComponentTP2 where SmartString: From<T> {
//         Ins(SmartString::from(s))
//     }
//
//     pub fn count(&self) -> usize {
//         match *self {
//             Skip(n) | Del(n) | InsTombstone(n) => n,
//             Ins(ref s) => str_indices::chars::count(s),
//         }
//     }
//     pub fn is_noop(&self) -> bool { self.count() == 0 }
//
//     // Could implement the slice operator for this?
//     pub fn slice(&self, offset: usize, len: usize) -> OpComponentTP2 {
//         debug_assert!(self.count() >= offset + len);
//         match *self {
//             Skip(_) => Skip(len),
//             Del(_) => Del(len),
//             // Move to slice_chars when available
//             // https://doc.rust-lang.org/1.2.0/std/primitive.str.html#method.slice_chars
//             Ins(ref s) => {
//                 let start_idx = str_indices::chars::to_byte_idx(s, offset);
//                 let r = &s[start_idx..];
//                 let end_idx = str_indices::chars::to_byte_idx(r, len);
//                 // Ins(s.chars().skip(offset).take(len).collect())
//                 Ins(r[..end_idx].into())
//             },
//             InsTombstone(_) => {
//                 todo!()
//             }
//         }
//     }
// }
//
// #[derive(Debug, PartialEq, Eq, Clone, Default)]
// pub struct TextOpTP2(pub SmallVec<[OpComponentTP2; 4]>);
// // pub struct TextOp (Vec<OpComponent>);
//
// impl TextOpTP2 {
//     pub fn new() -> Self {
//         TextOpTP2(smallvec![])
//         // TextOp(Vec::new())
//     }
//
//     // pub fn with_capacity(cap: usize) -> Self {
//     //     TextOp(Vec::with_capacity(cap))
//     // }
//
//     // TODO: Consider writing a version of this which takes ownership of the op component
//     pub fn append(&mut self, c: &OpComponentTP2) {
//         if c.is_noop() { return; }
//
//         match (self.0.last_mut(), c) {
//             (Some(Skip(a)), Skip(b))
//             | (Some(Del(a)), Del(b))
//             | (Some(InsTombstone(a)), InsTombstone(b)) => { *a += b },
//
//             (Some(Ins(a)), Ins(b)) => { a.push_str(b) },
//             _ => { self.0.push(c.clone()) }
//         }
//     }
//
//     pub fn append_move(&mut self, c: OpComponentTP2) {
//         if c.is_noop() { return; }
//
//         // Clean this up once non-lexical lifetimes lands
//         match (self.0.last_mut(), &c) {
//             (Some(Skip(a)), Skip(b))
//             | (Some(Del(a)), Del(b))
//             | (Some(InsTombstone(a)), InsTombstone(b)) => { *a += b; },
//
//             (Some(Ins(a)), Ins(b)) => { a.push_str(b); },
//
//             _ => {
//                 self.0.push(c);
//             }
//         }
//         // // Clean this up once non-lexical lifetimes lands
//         // if match (self.0.last_mut(), &c) {
//         //     (Some(Skip(a)), Skip(b))
//         //     | (Some(Del(a)), Del(b))
//         //     | (Some(InsTombstone(a)), InsTombstone(b)) => { *a += b; false },
//         //     (Some(Ins(a)), Ins(b)) => { a.push_str(b); false },
//         //     _ => true
//         // } { self.0.push(c); }
//     }
//
//     // By spec, text operations never end with (useless) trailing skip components.
//     pub fn trim(&mut self) {
//         while let Some(Skip(_)) = self.0.last() {
//             self.0.pop();
//         }
//     }
//
//     // // This is a very imperative solution. Maybe a more elegant way of doing
//     // // this would be to return an iterator to the resulting document... which
//     // // then you could collect() to realise into a new string.
//     // pub fn apply<D: EditableText>(&self, doc: &mut D) {
//     //     let mut pos = 0;
//     //
//     //     for c in &self.0 {
//     //         match c {
//     //             Skip(n) => pos += n,
//     //             Del(len) => doc.remove_at(pos, *len),
//     //             Ins(s) => {
//     //                 doc.insert_at(pos, s);
//     //                 pos += str_indices::chars::count(s);
//     //             }
//     //         }
//     //     }
//     // }
// }
//
// impl FromIterator<OpComponentTP2> for TextOpTP2 {
//     fn from_iter<I: IntoIterator<Item=OpComponentTP2>>(iter: I) -> Self {
//         let mut op = TextOpTP2::new();
//         for c in iter {
//             op.append(&c);
//         }
//         op
//     }
// }
//
//
// #[test]
// fn simple_apply() {
//     let op = TextOpTP2::from_iter(vec!(Skip(2), Ins(SmartString::from("hi"))));
//     let mut doc = "yo".to_string();
//     op.apply(&mut doc);
//     assert_eq!(doc, "yohi");
// }
//
//
// // ***** Transform & Compose code
//
// #[derive(Debug, PartialEq, Eq, Copy, Clone)]
// enum Context { Pre, Post }
//
// impl OpComponentTP2 {
//     // How much space this element takes up in the string before the op
//     // component is applied
//     fn pre_len(&self) -> usize {
//         match *self {
//             Skip(n) | Del(n) => n,
//             Ins(_) => 0,
//         }
//     }
//
//     fn post_len(&self) -> usize {
//         match *self {
//             Skip(n) => n,
//             Del(_) => 0,
//             Ins(ref s) => str_indices::chars::count(s),
//         }
//     }
//
//     fn ctx_len(&self, ctx: Context) -> usize {
//         match ctx {
//             Context::Pre => self.pre_len(),
//             Context::Post => self.post_len(),
//         }
//     }
// }
//
// struct TextOpIterator<'a> {
//     op: &'a TextOpTP2,
//
//     ctx: Context,
//     idx: usize,
//     offset: usize,
// }
//
// // I'd love to use a normal rust iterator here, but we need to pass in a limit
// // parameter each time we poll the iterator.
// impl <'a>TextOpIterator<'a> {
//     fn next(&mut self, max_size: usize) -> OpComponentTP2 {
//         // The op has an infinite skip at the end.
//         if self.idx == self.op.0.len() { return Skip(max_size); }
//
//         let c = &self.op.0[self.idx];
//         let clen = c.ctx_len(self.ctx);
//
//         if clen == 0 {
//             // The component is invisible in the context.
//             // TODO: Is this needed?
//             assert_eq!(self.offset, 0);
//             self.idx += 1;
//
//             // This is non ideal - if the compnent contains a large string we'll
//             // clone the string here. We could instead pass back a reference,
//             // but then the slices below will need to deal with lifetimes or be
//             // Rc or something.
//             c.clone()
//         } else if clen - self.offset <= max_size {
//             // Take remainder of component.
//             let result = c.slice(self.offset, clen - self.offset);
//             self.idx += 1;
//             self.offset = 0;
//             result
//         } else {
//             // Take max_size of the component.
//             let result = c.slice(self.offset, max_size);
//             self.offset += max_size;
//             result
//         }
//     }
// }
//
//
// impl TextOpTP2 {
//     fn iter(&self, ctx: Context) -> TextOpIterator {
//         TextOpIterator { op: self, ctx, idx: 0, offset: 0 }
//     }
//
//     fn is_valid(&self) -> bool {
//         // TODO.
//         true
//     }
//
//     fn append_remainder(&mut self, mut iter: TextOpIterator) {
//         loop {
//             let chunk = iter.next(usize::MAX);
//             if chunk == Skip(usize::MAX) { break; }
//             self.append_move(chunk);
//         }
//     }
// }
//
// pub fn transform_list(ops: &mut OpSet, other_ops: &[TextOpTP2], is_left: bool) {
//     if cfg!(debug_assertions) {
//         for o in ops.iter() {
//             debug_assert!(o.is_valid());
//         }
//         for o in other_ops {
//             debug_assert!(o.is_valid());
//         }
//     }
//
//     for mut o2 in other_ops.iter().cloned() {
//         for i in 0..ops.len() {
//             let (a, b) = transform2(&ops[i], &o2, is_left);
//             ops[i] = a;
//             o2 = b;
//         }
//     }
// }
//
// //
// // pub fn transform_list(ops: &[TextOp], other_ops: &[TextOp], is_left: bool) -> OpSet {
// //     if cfg!(debug_assertions) {
// //         for o in ops {
// //             debug_assert!(o.is_valid());
// //         }
// //         for o in other_ops {
// //             debug_assert!(o.is_valid());
// //         }
// //     }
// //
// //     // This code would be simpler if we first copy everything in ops into result, and then
// //     // work from there. But this is very performance sensitive, so I'll be a bit more careful here.
// //
// //     let mut iter = other_ops.iter().cloned();
// //
// //     let Some(first_other) = iter.next() else {
// //         return ops.iter().collect();
// //     };
// //     let mut result: OpSet = SmallVec::new();
// //
// //     let mut o2 = first_other;
// //     for op in ops {
// //         let (a, b) = transform2(op, &o2, is_left);
// //         result.push(a);
// //         o2 = b;
// //     }
// //
// //     // For the rest of the operations in other, we'll transform the entire result set.
// //     for mut o2 in iter {
// //         for i in 0..result.len() {
// //             let (a, b) = transform2(&result[i], &o2, is_left);
// //             result[i] = a;
// //             o2 = b;
// //         }
// //     }
// //
// //     result
// // }
//
// pub fn transform2(a: &TextOpTP2, b: &TextOpTP2, is_left: bool) -> (TextOpTP2, TextOpTP2) {
//     (
//         transform1(a, b, is_left),
//         transform1(b, a, !is_left)
//     )
// }
//
// pub fn transform1(op: &TextOpTP2, other: &TextOpTP2, is_left: bool) -> TextOpTP2 {
//     debug_assert!(op.is_valid() && other.is_valid());
//
//     let mut result = TextOpTP2::new();
//     let mut iter = op.iter(Context::Pre);
//
//     for c in &other.0 {
//         match c {
//             Skip(mut len) => { // Skip. Copy input to output.
//                 while len > 0 {
//                     let chunk = iter.next(len);
//                     len -= chunk.pre_len();
//                     result.append_move(chunk);
//                 }
//             },
//
//             Del(mut len) => {
//                 while len > 0 {
//                     let chunk = iter.next(len);
//                     len -= chunk.pre_len();
//
//                     // Discard all chunks except for inserts.
//                     if let Ins(s) = chunk {
//                         result.append_move(Ins(s));
//                     }
//                 }
//             },
//
//             Ins(_) => { // Write a corresponding skip.
//                 // Left's insert should go first.
//                 if is_left { result.append_move(iter.next(0)); }
//
//                 // Skip the text that otherop inserted.
//                 result.append_move(Skip(c.post_len()));
//             },
//         }
//     }
//
//     result.append_remainder(iter);
//     result.trim();
//     debug_assert!(result.is_valid());
//
//     result
// }
//
//
// pub fn compose(a: &TextOpTP2, b: &TextOpTP2) -> TextOpTP2 {
//     debug_assert!(a.is_valid() && b.is_valid());
//
//     let mut result = TextOpTP2::new();
//     let mut iter = a.iter(Context::Post);
//
//     for c in &b.0 {
//         match c {
//             Skip(mut len) => {
//                 // Copy len from a.
//                 while len > 0 {
//                     let chunk = iter.next(len);
//                     len -= chunk.post_len();
//                     result.append_move(chunk);
//                 }
//             },
//
//             Del(mut len) => {
//                 // Skip len items in a.
//                 while len > 0 {
//                     let chunk = iter.next(len);
//                     len -= chunk.post_len();
//                     // An if let .. would be better here once stable.
//                     match chunk {
//                         Skip(n) | Del(n) => { result.append_move(Del(n)); },
//                         _ => {} // Cancel inserts.
//                     }
//                 }
//             },
//
//             Ins(s) => {
//                 result.append_move(Ins(s.clone()));
//             }
//         }
//     }
//
//     result.append_remainder(iter);
//     result.trim();
//     debug_assert!(result.is_valid());
//
//     result
// }