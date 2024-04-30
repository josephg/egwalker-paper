use smallvec::{Array, SmallVec, smallvec};
use std::fmt::Debug;
use crate::cg::CausalGraph;

pub type LV = usize;

#[derive(Debug, Clone, Eq, PartialEq, Default, Hash, Ord, PartialOrd)]
pub struct Frontier(pub SmallVec<[usize; 2]>);


pub(crate) fn is_sorted_slice<const EXPECT_UNIQ: bool, V: Ord + Eq + Debug + Copy>(slice: &[V]) -> bool {
    if slice.len() >= 2 {
        let mut last = slice[0];
        for t in &slice[1..] {
            if EXPECT_UNIQ {
                debug_assert!(*t != last);
            }
            if last > *t || (EXPECT_UNIQ && last == *t) { return false; }
            last = *t;
        }
    }
    true
}

pub(crate) fn frontier_is_sorted(f: &[usize]) -> bool {
    // is_sorted_iter(f.iter().copied())
    is_sorted_slice::<true, _>(f)
}

pub(crate) fn sort_frontier<T: Array<Item=LV>>(v: &mut SmallVec<T>) {
    if !frontier_is_sorted(v.as_slice()) {
        v.sort_unstable();
    }
}


impl Frontier {
    pub fn root() -> Self {
        Self(smallvec![])
    }

    // pub fn new_1(v: LV) -> Self {
    //     Self(smallvec![v])
    // }

    pub fn from_unsorted(data: &[LV]) -> Self {
        let mut arr: SmallVec<[LV; 2]> = data.into();
        sort_frontier(&mut arr);
        Self(arr)
    }

    pub fn replace_with_1(&mut self, new_val: LV) {
        // I could truncate / etc, but this is faster in benchmarks.
        // replace(&mut self.0, smallvec::smallvec![new_val]);
        self.0 = smallvec::smallvec![new_val];
    }

    fn insert_nonoverlapping(&mut self, new_item: LV) {
        // In order to maintain the order of items in the branch, we want to insert the new item in the
        // appropriate place.

        // Binary search might actually be slower here than a linear scan.
        let new_idx = self.0.binary_search(&new_item).unwrap_err();
        self.0.insert(new_idx, new_item);
        debug_assert!(frontier_is_sorted(self.0.as_slice()));
    }

    /// Advance branch frontier by a transaction.
    ///
    /// This is ONLY VALID if the range is entirely within a txn.
    pub fn advance_by_known_run(&mut self, idx: usize, parents: &[LV]) {
        // TODO: Check the branch contains everything in txn_parents, but not txn_id:
        // Check the operation fits. The operation should not be in the branch, but
        // all the operation's parents should be.
        if parents.len() == 1 && self.0.len() == 1 && parents[0] == self.0[0] {
            // Short circuit the common case where time is just advancing linearly.
            self.0[0] = idx;
        } else if self.0.as_slice() == parents {
            self.replace_with_1(idx);
        } else {
            assert!(!self.0.contains(&idx));
            debug_assert!(frontier_is_sorted(self.0.as_slice()));

            self.0.retain(|o| !parents.contains(o)); // Usually removes all elements.

            // In order to maintain the order of items in the branch, we want to insert the new item
            // in the appropriate place. This will almost always do self.0.push(), but when changes
            // are concurrent that won't be correct. (Do it and run the tests if you don't believe
            // me).
            self.insert_nonoverlapping(idx);
        }
    }

    pub fn advance_by(&mut self, graph: &CausalGraph, idx: usize) {
        let entry = &graph.entries[idx];
        self.advance_by_known_run(idx, entry.parents.0.as_slice());
    }

}
