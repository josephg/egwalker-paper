// This is a simple causal graph implementation based on the equivalent in Diamond Types.

use std::collections::BinaryHeap;
use std::fmt::Debug;
use smallvec::{SmallVec, smallvec};
use crate::frontier::{Frontier, LV};

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct GraphEntryInternal {
    idx: usize,

    /// Set of indexes of the parent items.
    pub parents: Frontier,

    // /// This is a cached list of all the other indexes of items in history which name this item as
    // /// a parent. Its very useful in a few specific situations - and I've gone back and forth on
    // /// whether its worth keeping this field.
    // pub child_indexes: SmallVec<[usize; 2]>,
}

#[derive(Clone, Debug, Default)]
pub struct CausalGraph {
    pub entries: Vec<GraphEntryInternal>,
    pub frontier: Frontier,
}

// OnlyA, OnlyB.
pub(crate) type DiffResult = (SmallVec<[usize; 4]>, SmallVec<[usize; 4]>);

#[derive(Copy, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) enum DiffFlag { OnlyA, OnlyB, Shared }

impl CausalGraph {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn push(&mut self, idx: usize, parents: &[usize]) {
        self.entries.push(GraphEntryInternal {
            idx,
            parents: Frontier(parents.into()),
        });

        // And update the frontier.
        self.frontier.advance_by_known_run(idx, parents);
    }

    pub fn diff(&self, a: &[LV], b: &[LV]) -> DiffResult {
        let mut result = self.diff_rev(a, b);
        result.0.reverse();
        result.1.reverse();
        result
    }

    fn diff_rev(&self, a: &[LV], b: &[LV]) -> DiffResult {
        use DiffFlag::*;

        // Sorted highest to lowest.
        let mut queue: BinaryHeap<(LV, DiffFlag)> = BinaryHeap::new();
        for a_ord in a {
            queue.push((*a_ord, OnlyA));
        }
        for b_ord in b {
            queue.push((*b_ord, OnlyB));
        }

        let mut num_shared_entries = 0;

        let mut only_a = smallvec![];
        let mut only_b = smallvec![];

        while let Some((idx, mut flag)) = queue.pop() {
            if flag == Shared { num_shared_entries -= 1; }

            // dbg!((ord, flag));
            while let Some((peek_idx, peek_flag)) = queue.peek() {
                if *peek_idx != idx { break; } // Normal case.
                else {
                    // 3 cases if peek_flag != flag. We set flag = Shared in all cases.
                    if *peek_flag != flag { flag = Shared; }
                    if *peek_flag == Shared { num_shared_entries -= 1; }
                    queue.pop();
                }
            }

            match flag {
                OnlyA => { only_a.push(idx); }
                OnlyB => { only_b.push(idx); }
                Shared => {}
            }

            for p in self.entries[idx].parents.0.iter() {
                queue.push((*p, flag));
                if flag == Shared { num_shared_entries += 1; }
            }

            // If there's only shared entries left, abort.
            if queue.len() == num_shared_entries { break; }
        }

        (only_a, only_b)
    }
}

#[cfg(test)]
mod test {
    use crate::cg::CausalGraph;

    #[test]
    fn frontier_updates_correctly() {
        let mut cg = CausalGraph::new();
        cg.push(0, &[]);
        assert_eq!(cg.frontier.0.as_slice(), &[0]);
        cg.push(1, &[0]);
        assert_eq!(cg.frontier.0.as_slice(), &[1]);
        cg.push(2, &[0]);
        assert_eq!(cg.frontier.0.as_slice(), &[1, 2]);
        cg.push(3, &[1, 2]);
        assert_eq!(cg.frontier.0.as_slice(), &[3]);
        // dbg!(&cg);
    }
}