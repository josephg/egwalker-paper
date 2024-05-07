// #import "@preview/cetz:0.1.2": canvas, plot, draw
// #import "@preview/fletcher:0.2.0" as fletcher: node, edge
#import "@preview/fletcher:0.3.0" as fletcher: node, edge
#import "@preview/ctheorems:1.1.0": *
#import "@preview/algo:0.3.3": algo, i, d, comment, code
// #import "@preview/lovelace:0.1.0": *
#import "@preview/algorithmic:0.1.0": algorithm
#import "@preview/cetz:0.1.2"
#import "charts.typ"
#show: thmrules

#let anonymous = true
#let algname = "Eg-walker"
#if anonymous {
  algname = "Feathertail"
}

#set page(
  paper: "a4",
  numbering: "1",
  // 178 × 229 mm text block on an A4 page (210 × 297 mm)
  margin: (x: (210 - 178) / 2 * 1mm, y: (297 - 229) / 2 * 1mm),
)

// 10pt text with 12pt leading
#set text(font: "Linux Libertine", size: 10pt)
#let spacing = 0.55em
#set par(justify: true, first-line-indent: 1em, leading: spacing)
#show par: set block(spacing: spacing)
//#show math.equation: set text(font: "Libertinus Math")

#set heading(numbering: "1.1.1")

// Heading formatting from https://gist.github.com/vtta/d6268ba81ebfdd1dc573db4b72df8436
#show heading: it => locate(loc => {
  // Find out the final number of the heading counter.
  let levels = counter(heading).at(loc)
  let deepest = if levels != () { levels.last() } else { 1 }
  v(2 * spacing, weak: true)
  if it.level == 1 {
    let no-numbering = it.body in ([Abstract], [Acknowledgments], [Acknowledgment])
    block(text(size: 12pt, {
      if it.numbering != none and not no-numbering{ 
        numbering(it.numbering, ..levels)
        h(spacing, weak: true)
      }
      it.body
      v(1.5 * spacing, weak: true)
    }))
  } else if it.level == 2 {
    block(text(size: 10pt,{
      if it.numbering != none { 
        numbering(it.numbering, ..levels)
        h(spacing, weak: true)
      }
      it.body
      v(1.5 * spacing, weak: true)
    }))
  } else {
    if it.numbering != none { 
      h(-1em)
      numbering(it.numbering, ..levels)
      h(spacing, weak: true)
    }
    it.body + [.]
  }
})

#set enum(indent: 10pt, body-indent: 9pt)
#set list(indent: 10pt, body-indent: 9pt)

#show figure.where(kind: table): set figure.caption(position: top)

#show figure.caption: it => align(left, par(first-line-indent: 0pt, [
  #text(weight: "bold", [#it.supplement #it.counter.display(it.numbering).])
  #it.body
]))

#let definition = thmbox("definition", "Definition",
  base_level: 0,
  fill: rgb("#f8e8e8")
)

#let claim = thmbox("claim", "Claim",
  base_level: 0,
  fill: rgb("#e8e8f8")
)

#if anonymous {
  align(center, text(20pt)[*Fast and memory-efficient collaborative text editing*])
  align(center, text(12pt)[
    Anonymous Author(s) \
    Submission ID: TODO
  ])
} else {
  align(center, text(20pt)[*Collaborative Text Editing: Better, Faster, Smaller*])
  grid(
    columns: (1fr, 1fr),
    align(center, text(12pt)[
      Joseph Gentle \
      #link("mailto:me@josephg.com")
    ]),

    align(center, text(12pt)[
      Martin Kleppmann \
      University of Cambridge, UK \
      #link("mailto:martin@kleppmann.com")
    ])
  )
}

#show: columns.with(2, gutter: 8mm)

#heading(numbering: none, [Abstract])

Collaborative text editing algorithms allow several users to concurrently modify a text file, and automatically merge concurrent edits into a consistent state.
Existing algorithms fall in two categories: Operational Transformation (OT) algorithms are slow to merge files that have diverged substantially due to offline editing; CRDTs are slow to load and consume a lot of memory.
We introduce #algname, a collaboration algorithm for text that avoids these weaknesses.
Compared to existing CRDTs, it consumes an order of magnitude less memory in the steady state, and loading a document from disk is orders of magnitude faster.
Compared to OT, merging long-running branches is orders of magnitude faster.
In the worst case, the merging performance of #algname is comparable with existing CRDT algorithms.
#algname can be used everywhere CRDTs are used, including peer-to-peer systems without a central server.
By offering performance that is competitive with centralised algorithms, our result paves the way towards the widespread adoption of peer-to-peer collaboration software.


= Introduction <introduction>

Real-time collaboration has become an essential feature for many types of software, including document editors such as Google Docs, Microsoft Word, or Overleaf, and graphics software such as Figma.
In such software, each user's device locally maintains a copy of the shared file (e.g. in a tab of their web browser).
A user's edits are immediately applied to their own local copy, without waiting for a network round-trip, so that the user interface is responsive regardless of network latency.
Different users may therefore make edits concurrently, and the software must merge such concurrent edits in a way that preserves the users' intentions, and ensure that all devices converge to the same state.

For example, in @two-inserts, two users initially have the same document "Helo".
User 1 inserts a second letter "l" at index 3, while concurrently user 2 inserts an exclamation mark at index 4.
When user 2 receives the operation $italic("Insert")(3, \"l\")$ it can apply it to obtain "Hello!", but when user 1 receives $italic("Insert")(4, \"!\")$ it cannot apply that operation as-is, since that would result in the state "Hell!o", which would be inconsistent with the other user's state and the intended insertion position.
Due to the concurrent insertion at an earlier index, user 1 must insert the exclamation mark at index 5.

#figure(
  fletcher.diagram({
    let (left1, right1, left2, right2, left3, right3) = ((0,2), (2,2), (0,1), (2,1), (0,0), (2,0))
    node((0,2.4), "User 1:")
    node((2,2.4), "User 2:")
    node(left1, `Helo`)
    node(left2, `Hello`)
    node(left3, `Hello!`)
    node(right1, `Helo`)
    node(right2, `Helo!`)
    node(right3, `Hello!`)
    edge(left1, left2, $italic("Insert")(3, \"l\")$, "->", label-side: right)
    edge(right1, right2, $italic("Insert")(4, \"!\")$, "->", label-side: left)
    edge(left2, left3, $italic("Insert")(5, \"!\")$, "->", label-side: right)
    edge(right2, right3, $italic("Insert")(3, \"l\")$, "->", label-side: left)
    edge((0.1,1.5), (1.9,0.5), "->", "dashed")
    edge((1.9,1.5), (0.1,0.5), "->", "dashed")
  }),
  placement: top,
  caption: [Two concurrent insertions into a text document.],
) <two-inserts>

One way of solving this problem is to use _Operational Transformation_ (OT): when user 1 receives $italic("Insert")(4, \"!\")$ that operation is transformed with regard to the concurrent insertion at index 3, which increments the index at which the exclamation mark is inserted.
OT is an old and widely-used technique: it was introduced in 1989 @Ellis1989, and the OT algorithm Jupiter @Nichols1995 forms the basis of real-time collaboration in Google Docs @DayRichter2010.

// Seph: I'm not sure how much people care about the theoretical complexity of OT this early in the paper. Might be better to ground it in some real world benchmarking.
OT is simple and fast in the case of @two-inserts, where each user performed only one operation since the last version they had in common.
In general, if the users each performed $n$ operations since their last common version, merging their states using OT has a cost of at least $O(n^2)$, since each of one user's operations must be transformed with respect to all of the other user's operations.
Some OT algorithms have a merge complexity that is cubic or even slower @Li2006 @Roh2011RGA @Sun2020OT.
This is acceptable for online collaboration where $n$ is typically small, but if users may edit a document offline or if the software supports explicit branching and merging workflows @Upwelling, an algorithm with complexity $O(n^2)$ can become impracticably slow.
In @benchmarking we show a real-life example document that takes one hour to merge using OT.

_Conflict-free Replicated Data Types_ (CRDTs) have been proposed as an alternative to OT.
The first CRDT for collaborative text editing appeared in 2006 @Oster2006WOOT, and over a dozen text CRDTs have been published since @crdt-papers.
These algorithms work by giving each character a unique identifier, and using those IDs instead of integer indexes to identify the position of insertions and deletions.
This avoids having to transform operations, since IDs are not affected by concurrent operations.
Unfortunately, these IDs need to be held in memory while a document is being edited; even with careful optimisation, this metadata uses more than 10 times more memory than the document text, and makes documents much slower to load from disk.
Some CRDT algorithms also need to retain IDs of deleted characters (_tombstones_).

In this paper we propose #if anonymous { algname } else { [_Event Graph Walker_ (#algname)] }, a collaborative editing algorithm that has the strengths of both OT and CRDTs but not their weaknesses.
Like OT, #algname uses integer indexes to identify insertion and deletion positions, and transforms those indexes to merge concurrent operations.
When two users concurrently perform $n$ operations each, #algname can merge them at a cost of $O(n log n)$, much faster than OT's cost of $O(n^2)$ or worse.

#algname merges concurrent edits using a CRDT algorithm we designed.
Unlike existing algorithms, we invoke the CRDT only to perform merges of concurrent operations, and we discard its state as soon as the merge is complete.
We never write the CRDT state to disk and never send it over the network.
While a document is being edited, we only hold the document text in memory, but no CRDT metadata.
Most of the time, #algname therefore uses 1–2 orders of magnitude less memory than a CRDT.
During merging, when #algname temporarily uses more memory, its peak memory use is comparable to the best known CRDT implementations.

#algname assumes no central server, so it can be used over a peer-to-peer network.
Although all existing CRDTs and a few OT algorithms can be used peer-to-peer, most of them have poor performance compared to the centralised OT used in production software such as Google Docs.
In contrast, #algname's performance matches or surpasses that of centralised algorithms.
It therefore paves the way towards the widespread adoption of peer-to-peer collaboration software, and perhaps overcoming the dominance of centralised cloud software that exists in the market today.

Collaboration on plain text files is the first application for #algname.
We believe that our approach can be generalised to other file types such as rich text, spreadsheets, graphics, presentations, CAD drawings, and more.
More generally, #algname provides a framework for efficient coordination-free distributed systems, in which nodes can always make progress independently, but converge eventually @Hellerstein2010.

This paper makes the following contributions:

- In @algorithm we introduce #algname, a hybrid CRDT/OT algorithm for text that is faster and has a vastly smaller memory footprint than existing CRDTs.
- Since there is no established benchmark for collaborative text editing, we are also publishing a suite of editing traces of text files for benchmarking. They are derived from real documents and demonstrate various patterns of sequential and concurrent editing.
- In @benchmarking we use those editing traces to evaluate the performance of our implementation of #algname, comparing it to selected CRDTs and an OT implementation. We measure CPU time to load a document, CPU time to merge edits from a remote replica, memory usage, and file size. #algname improves the state of the art by orders of magnitude in the best cases, and is only slightly slower in the worst cases.
- We prove the correctness of #algname in @proofs.

= Background

We consider a collaborative plain text editor whose state is a linear sequence of characters, which may be edited by inserting or deleting characters at any position.
Such an edit is captured as an _operation_; we use the notation $italic("Insert")(i, c)$ to denote an operation that inserts character $c$ at index $i$, and $italic("Delete")(i)$ deletes the character at index $i$ (indexes are zero-based).
Our implementation compresses runs of consecutive insertions or deletions, but for simplicity we describe the algorithm in terms of single-character operations.

== System model

Each device on which a user edits a document is a _replica_, and each replica stores its full editing history.
When a user makes an insertion or deletion, that operation is immediately applied to the user's local replica, and then asynchronously sent over the network to any other replicas that have a copy of the same document.
Users can also edit their local copy while offline; the corresponding operations are then enqueued and sent when the device is next online.

Our algorithm makes no assumptions about the underlying network via which operations are replicated: any reliable broadcast protocol (which detects and retransmits lost messages) is sufficient.
For example, a relay server could store and forward messages from one replica to the others, or replicas could use a peer-to-peer gossip protocol.
We make no timing assumptions and can tolerate arbitrary network delay, but we assume replicas are non-Byzantine.

A key property that the collaboration algorithm must satisfy is _convergence_: any two replicas that have seen the same set of operations must be in the same document state (i.e., a text consisting of the same sequence of characters), even if the operations arrived in a different order at each replica.
If the underlying broadcast protocol ensures that every non-crashed replica eventually receives every operation, the algorithm achieves _strong eventual consistency_ @Shapiro2011.

== Event graphs

We represent the editing history of a document as an _event graph_: a directed acyclic graph (DAG) in which every node is an _event_ consisting of an operation (insert/delete a character), a unique ID, and a set of IDs of its _parent nodes_.
When $a$ is a _parent_ of $b$, we also say $b$ is a _child_ of $a$, and the graph contains an edge from $a$ to $b$.
We construct events such that the graph is transitively reduced (i.e., it contains no redundant edges).
When there is a directed path from $a$ to $b$ we say that $a$ _happened before_ $b$, and write $a -> b$ as per Lamport @Lamport1978.
The $->$ relation is a strict partial order.
We say that events $a$ and $b$ are _concurrent_, written $a parallel b$, if both events are in the graph, $a eq.not b$, and neither happened before the other: $a arrow.r.not b and b arrow.r.not a$.

The _frontier_ is the set of events with no children.
Whenever a user performs an operation, a new event containing that operation is added to the graph, and the previous frontier in the replica's local copy of the graph becomes the new event's parents.
The new event and its parent edges are then replicated over the network, and each replica adds them to its copy of the graph.
If any parent events are missing, the replica waits for them to arrive before adding them to the graph; the result is a simple causal broadcast protocol @Birman1991 @Cachin2011.
Two replicas can merge their event graphs by simply taking the union of their sets of events.
Events in the graph are immutable; they always represents the operation as originally generated, and not as a result of any transformation.

#figure(
  fletcher.diagram(node-inset: 6pt, node-defocus: 0, {
    let (char1, char2, char3, char4, char5, char6) = ((0,2), (0,1.5), (0,1), (0,0.5), (-0.5,0), (0.5,0))
    node(char1, $e_1: italic("Insert")(0, \"H\")$)
    node(char2, $e_2: italic("Insert")(1, \"e\")$)
    node(char3, $e_3: italic("Insert")(2, \"l\")$)
    node(char4, $e_4: italic("Insert")(3, \"o\")$)
    node(char5, $e_5: italic("Insert")(3, \"l\")$)
    node(char6, $e_6: italic("Insert")(4, \"!\")$)
    edge(char1, char2, "-|>")
    edge(char2, char3, "-|>")
    edge(char3, char4, "-|>")
    edge(char4, char5, "-|>")
    edge(char4, char6, "-|>")
  }),
  placement: top,
  caption: [The event graph corresponding to @two-inserts.],
) <graph-example>

For example, @graph-example shows the event graph corresponding to @two-inserts.
The events $e_5$ and $e_6$ are concurrent, and the frontier of this graph is the set of events ${e_5, e_6}$.

The event graph for a substantial document, such as a research paper, may contain hundreds of thousands of events.
It can nevertheless be stored in a very compact form by exploiting the typical editing patterns of humans writing text: characters tend to be inserted or deleted in consecutive runs.
Many portions of a typical event graph are linear, with each event having one parent and one child.
We describe the storage format in more detail in @storage.

== Document versions <versions>

Let $G$ be an event graph, represented as a set of events.
Due to convergence, any two replicas that have the same set of events must be in the same state.
Therefore, the document state (sequence of characters) resulting from $G$ must be $sans("replay")(G)$, where $sans("replay")$ is some pure (deterministic and non-mutating) function.
In principle, any pure function of the set of events results in convergence, although a $sans("replay")$ function that is useful for text editing must satisfy additional criteria (see @characteristics).

Consider the event $italic("Delete")(i)$, which deletes the character at position $i$ in the document. In order to correctly interpret this event, we need to determine which character was at index $i$ at the time when the operation was generated.

More generally, let $e_i$ be some event. The document state when $e_i$ was generated must be $sans("replay")(G_i)$, where $G_i$ is the set of events that were known to the generating replica at the time when $e_i$ was generated (not including $e_i$ itself).
By definition, the parents of $e_i$ are the frontier of $G_i$, and thus $G_i$ is the set of all events that happened before $e_i$, i.e., $e_i$'s parents and all of their ancestors.
Therefore, the parents of $e_i$ unambiguously define the document state in which $e_i$ must be interpreted.

To formalise this, given an event graph (set of events) $G$, we define the _version_ of $G$ to be its frontier set:

$ sans("Version")(G) = {e_1 in G | exists.not e_2 in G: e_1 -> e_2} $

Given some version $V$, the corresponding set of events can be reconstructed as follows:

$ sans("Events")(V) = V union {e_1 | exists e_2 in V : e_1 -> e_2} $

Since an event graph grows only by adding events that are concurrent to or children of existing events (we never change the parents of an existing event), there is a one-to-one correspondence between an event graph and its version.
Hence, for all valid event graphs $G$, we have $sans("Events")(sans("Version")(G)) = G$.

The set of parents of an event in the graph is the version of the document in which that operation must be interpreted.
The version can hence also be seen as a _logical clock_, describing the point in time at which a replica knows about the exact set of events in $G$.
Even if the event graph is large, a version rarely consists of more than two events in practice.

== Replaying editing history

Collaborative editing algorithms are usually defined in terms of sending and receiving messages over a network.
The abstraction of an event graph allows us to reframe these algorithms in a simpler way: a collaborative text editing algorithm is a pure function $sans("replay")(G)$ of an event graph $G$.
This function can use the parent-child relationships to partially order events, but concurrent events could be processed in any order.
This allows us to separate the process of replicating the event graph from the algorithm that ensures convergence.
In fact, this is how _pure operation-based CRDTs_ @polog are formulated, as discussed in @related-work.

In addition to determining the document state from an entire event graph, we need an _incremental update_ function.
Say we have an existing event graph $G$ and corresponding document state $italic("doc") = sans("replay")(G)$. Then an event $e$ from a remote replica is added to the graph.
We could rerun the function to obtain $italic("doc")' = sans("replay")(G union {e})$, but it would be inefficient to process the entire graph again.
Instead, we need to efficiently compute the operation to apply to $italic("doc")$ in order to obtain $italic("doc")'$.
For text documents, this incremental update is also described as an insertion or deletion at a particular index; however, the index may differ from that in the original event due to the effects of concurrent operations, and a deletion may turn into a no-op if the same character has also been deleted by a concurrent operation.

Both OT and CRDT algorithms focus on this incremental update.
If none of the events in $G$ are concurrent with $e$, OT is straightforward: the incremental update is identical to the operation in $e$, as no transformation takes place.
If there is concurrency, OT must transform each new event with regard to each existing event that is concurrent to it.

In CRDTs, each event is first translated into operations that use unique IDs instead of indexes, and then these operations are applied to a data structure that reflects all of the operations seen so far (both concurrent operations and those that happened before).
In order to update the text editor, these updates to the CRDT's internal structure need to be translated back into index-based insertions and deletions.
Many CRDT papers elide this translation from unique IDs back to indexes, but it is important for practical applications. // - such as updating specialised buffers inside text editors, and updating user cursor positions.

// Seph: If we want to cut down on the length of the paper, we could probably remove this.

// - Text editors use specialised data structures such as piece trees @vscode-buffer to efficiently edit large documents, and integrating with these structures requires index-based operations. Incrementally updating these structures also enables syntax highlighting without having to repeatedly parse the whole file on every keystroke.
// - The user's cursor position in a document can be represented as an index; if another user changes text earlier in the document, index-based operations make it easy to update the cursor so that it remains in the correct position relative to the surrounding text.

Regardless of whether the OT or the CRDT approach is used, a collaborative editing algorithm can be boiled down to an incremental update to an event graph: given an event to be added to an existing event graph, return the (index-based) operation that must be applied to the current document state so that the resulting document is identical to replaying the entire event graph including the new event.

// (seph): ^-- this is a very bold statement.

#if anonymous {
  [= The #algname algorithm <algorithm>]
} else {
  [= The Event Graph Walker algorithm <algorithm>]
}

// While OT transforms one operation with respect to one other operation, #algname builds a temporary data structure that reflects the concurrent edits, and uses it to operations efficiently.

#algname is a collaborative text editing algorithm based on the idea of event graph replay.
The algorithm builds on a replication layer that ensures that whenever a replica adds an event to the graph, all non-crashed replicas eventually receive it.
The state of each replica consists of three parts:

1. *Event graph:* Each replica stores a copy of the event graph on disk, in a format described in @storage.
2. *Document state:* The current sequence of characters in the document with no further metadata. On disk this is simply a plain text file; in memory it may be represented as a rope @Boehm1995, piece table @vscode-buffer, or similar structure to support efficient insertions and deletions.
3. *Internal state:* A temporary CRDT structure that #algname uses to merge concurrent edits. It is not persisted or replicated, and it is discarded when the algorithm finishes running.

#algname can reconstruct the document state by replaying the entire event graph.
It first performs a topological sort, as illustrated in @topological-sort. Then each event is transformed so that the transformed insertions and deletions can be applied in topologically sorted order, starting with an empty document, to obtain the document state.
In Git parlance, this process "rebases" a DAG of operations into a linear operation history with the same effect.
The input of the algorithm is the event graph, and the output is this topologically sorted sequence of transformed operations.

In graphs with concurrent operations there are multiple possible sort orders. #algname guarantees that the final document state is the same, regardless which of these orders is chosen. However, the choice of sort order may affect the performance of the algorithm, as discussed in @complexity.

#figure(
  fletcher.diagram(node-inset: 2pt, node-stroke: black, node-fill: black, {
    let (a1, a2, a3, a4, a5, a6) = ((0,2), (0,1.5), (0,1), (0,0.5), (0,0), (0,-0.5))
    let (b1, b2, b3, b4) = ((1,1.5), (1,1), (1,0.5), (1,0))
    let (c1, c2, c3) = ((-1,1), (-1,0.5), (-1,0))
    let (x1, x2, x3, x4, x5, x6, x7) = ((4,2), (4,1.5), (4,1), (4,0.5), (4,0), (4,-0.5), (4,-1))
    let (x8, x9, x10, x11, x12, x13) = ((5,2), (5,1.5), (5,1), (5,0.5), (5,0), (5,-0.5))
    node(a1, text(0.1em, $a$))
    node(a2, text(0.1em, $a$))
    node(a3, text(0.1em, $a$))
    node(a4, text(0.1em, $a$))
    node(a5, text(0.1em, $a$))
    node(a6, text(0.1em, $a$))
    node(b1, text(0.1em, $a$))
    node(b2, text(0.1em, $a$))
    node(b3, text(0.1em, $a$))
    node(b4, text(0.1em, $a$))
    node(c1, text(0.1em, $a$))
    node(c2, text(0.1em, $a$))
    node(c3, text(0.1em, $a$))
    node(x1, text(0.1em, $a$))
    node(x2, text(0.1em, $a$))
    node(x3, text(0.1em, $a$))
    node(x4, text(0.1em, $a$))
    node(x5, text(0.1em, $a$))
    node(x6, text(0.1em, $a$))
    node(x7, text(0.1em, $a$))
    node(x8, text(0.1em, $a$))
    node(x9, text(0.1em, $a$))
    node(x10, text(0.1em, $a$))
    node(x11, text(0.1em, $a$))
    node(x12, text(0.1em, $a$))
    node(x13, text(0.1em, $a$))
    edge(a1, a2, $e_"A1"$, "-|>", label-pos: 0)
    edge(a2, a3, $e_"A2"$, "-|>", label-pos: 0, label-side: left)
    edge(a3, a4, $e_"A3"$, "-|>", label-pos: 0)
    edge(a4, a5, $e_"A4"$, "-|>", label-pos: 0)
    edge(a5, a6, $e_"A5"$, "-|>", label-pos: 0)
    edge(a5, (0,-0.55), $e_"A6"$, label-pos: 1, label-side: left)
    edge(b1, b2, $e_"B1"$, "-|>", label-pos: 0, label-side: left)
    edge(b2, b3, $e_"B2"$, "-|>", label-pos: 0, label-side: left)
    edge(b3, b4, $e_"B3"$, "-|>", label-pos: 0, label-side: left)
    edge(b3, (1,-0.05), $e_"B4"$, label-pos: 1, label-side: left)
    edge(c1, c2, $e_"C1"$, "-|>", label-pos: 0)
    edge(c2, c3, $e_"C2"$, "-|>", label-pos: 0)
    edge(c2, (-1,-0.05), $e_"C3"$, label-pos: 1)
    edge(a1, b1, "-|>", bend: +20deg)
    edge(a3, b3, "-|>")
    edge(b2, a5, "-|>")
    edge(a2, c1, "-|>", bend: -20deg)
    edge(c3, a6, "-|>")
    edge(x1, x2, $e_"A1"$, "-|>", label-pos: 0)
    edge(x2, x3, $e_"A2"$, "-|>", label-pos: 0)
    edge(x3, x4, $e_"A3"$, "-|>", label-pos: 0)
    edge(x4, x5, $e_"A4"$, "-|>", label-pos: 0)
    edge(x5, x6, $e_"B1"$, "-|>", label-pos: 0)
    edge(x6, x7, $e_"B2"$, "-|>", label-pos: 0)
    edge(x6, (4,-1.05), $e_"B3"$, label-pos: 1)
    edge(x7, x8, "-|>")
    edge(x8, x9, $e_"B4"$, "-|>", label-pos: 0, label-side: left)
    edge(x9, x10, $e_"C1"$, "-|>", label-pos: 0, label-side: left)
    edge(x10, x11, $e_"C2"$, "-|>", label-pos: 0, label-side: left)
    edge(x11, x12, $e_"C3"$, "-|>", label-pos: 0, label-side: left)
    edge(x12, x13, $e_"A5"$, "-|>", label-pos: 0, label-side: left)
    edge(x12, (5,-0.55), $e_"A6"$, label-pos: 1, label-side: left)
  }),
  placement: top,
  caption: [An event graph (left) and one possible topologically sorted order of that graph (right).],
) <topological-sort>

For example, the graph in @graph-example has two possible sort orders; #algname either first inserts "l" at index 3 and then the exclamation mark at index 5 (like User 1 in @two-inserts), or first inserts "!" at index 4 followed by "l" at index 3 (like User 2 in @two-inserts); the final document state is "Hello!" either way.

Event graph replay easily extends to incremental updates for real-time collaboration: when a new event is added to the graph, it becomes the next element of the topologically sorted sequence.
We can transform each new event in the same way as during replay, and apply the transformed operation to the current document state.

== Characteristics of #algname <characteristics>

#algname ensures that the resulting document state is consistent with Attiya et al.'s _strong list specification_ @Attiya2016 (in essence, replicas converge to the same state and apply operations in the right place), and it is _maximally non-interleaving_ @fugue (i.e., concurrent sequences of insertions at the same position are placed one after another, and not interleaved).

One way of achieving this goal would be to track the state of each branch of the editing history in a separate CRDT object.
The CRDT for a given branch could translate events from the event graph into the corresponding CRDT operations.
When branches fork, the CRDT object would need to be cloned in memory.
When branches merge, CRDT operations from one branch would be applied to the other branch's CRDT state.
Essentially, this approach simulates a network of communicating CRDT replicas and their states.
This approach produces the correct result, but it performs poorly, as we need to store and update a full copy of the CRDT state for every concurrent branch in the event graph.

// (Seph): We have benchmark data for this approach btw.

#algname improves on this approach in two ways:

1. #algname avoids the need to clone and merge multiple CRDT objects. Instead, the algorithm maintains a single data structure that can transform and merge events from multiple branches.
2. In portions of the event graph that have no concurrency (which, in many editing histories, is the vast majority of events), events do not need to be transformed at all, and we can discard all of the internal state accumulated so far.

Moreover, #algname does not need the event graph and the internal state when generating new events, or when adding an event to the graph that happened after all existing events.
Most of the time, we only need the current document state.
The event graph can remain on disk without using any space in memory or any CPU time.
The event graph is only required when handling concurrency, and even then we only have to replay the portion of the graph since the last ancestor that the concurrent operations had in common.

#algname's approach contrasts with existing CRDTs, which require every replica to persist the internal state (including the unique ID for each character) and send it over the network, and which require that state to be loaded into memory in order to both generate and receive operations, even when there is no concurrency.
This can use significant amounts of memory and can make documents slow to load.

OT algorithms avoid this internal state; similarly to #algname, they only need to persist the latest document state and the history of operations that are concurrent to operations that may arrive in the future.
In both #algname and OT, the editing history/event graph can be discarded if we know that no event we may receive in the future will be concurrent with any existing event.
However, OT algorithms have asymptotically worse performance than #algname in transforming concurrent operations (see @complexity).
Some OT algorithms are only able to handle restricted forms of event graphs, whereas #algname handles arbitrary DAGs.

== Walking the event graph <graph-walk>

For the sake of clarity we first explain a simplified version of #algname that replays the entire event graph without discarding its internal state along the way. This approach incurs some CRDT overhead even for non-concurrent operations.
In @partial-replay we show how the algorithm can be optimised to replay only a part of the event graph.

First, we topologically sort the event graph in a way that keeps events on the same branch consecutive as much as possible: for example, in @topological-sort we first visit $e_"A1" ... e_"A4"$, then $e_"B1" ... e_"B4"$. We avoid alternating between branches, such as $e_"A1", e_"B1", e_"A2", e_"B2" ...$, even though that would also be a valid topological sort.
For this we use a standard textbook algorithm @CLRS2009: perform a depth-first traversal starting from the oldest event, and build up the topologically sorted list in the order that events are visited.
When a node has multiple children in the graph, we choose their order based on a heuristic so that branches with fewer events tend to appear before branches with more events in the sorted order; this can improve performance but is not essential.
We estimate the size of a branch by counting the number of events that happened after each event.

The algorithm then processes the events one at a time in topologically sorted order, updating the internal state and outputting a transformed operation for each event.
The internal state simultaneously captures the document at two versions: the version in which an event was generated (which we call the _prepare_ version), and the version in which all events seen so far have been applied (which we call the _effect_ version).
If the prepare and effect versions are the same, the transformed operation is identical to the original one.
In general, the prepare version represents a subset of the events of the effect version.
// Due to the topological sorting it is not possible for the prepare version to be later than the effect version.

The internal state can be updated with three methods, each of which takes an event as argument:

- $sans("apply")(e)$ updates the prepare version and the effect version to include $e$, assuming that the current prepare version equals $e.italic("parents")$, and that $e$ has not yet been applied. This method interprets $e$ in the context of the prepare version, and outputs the operation representing how the effect version has been updated.
- $sans("retreat")(e)$ updates the prepare version to remove $e$, assuming the prepare version previously included $e$.
- $sans("advance")(e)$ updates the prepare version to add $e$, assuming that the prepare version previously did not include $e$, but the effect version did.

#figure(
  fletcher.diagram(node-inset: 6pt, node-defocus: 0, {
    let (e1, e2, e3, e4, e5, e6, e7, e8) = ((0.5,2.5), (0.5,2), (0,1.5), (0,1), (1,1.5), (1,1), (1,0.5), (0.5,0))
    node(e1, $e_1: italic("Insert")(0, \"h\")$)
    node(e2, $e_2: italic("Insert")(1, \"i\")$)
    node(e3, $e_3: italic("Insert")(0, \"H\")$)
    node(e4, $e_4: italic("Delete")(1)$)
    node(e5, $e_5: italic("Delete")(1)$)
    node(e6, $e_6: italic("Insert")(1, \"e\")$)
    node(e7, $e_7: italic("Insert")(2, \"y\")$)
    node(e8, $e_8: italic("Insert")(3, \"!\")$)
    edge(e1, e2, "-|>")
    edge(e2, e3, "-|>")
    edge(e3, e4, "-|>")
    edge(e2, e5, "-|>")
    edge(e5, e6, "-|>")
    edge(e6, e7, "-|>")
    edge(e7, e8, "-|>")
    edge(e4, e8, "-|>")
  }),
  placement: top,
  caption: [An event graph. Starting with document "hi", one user changes "hi" to "hey", while concurrently another user capitalises the "H". After merging to the state "Hey", one of them appends an exclamation mark to produce "Hey!".],
) <graph-hi-hey>

The effect version only moves forwards in time (through $sans("apply")$), whereas the prepare version can move both forwards and backwards.
Consider the example in @graph-hi-hey, and assume that the events $e_1 ... e_8$ are traversed in order of their subscript.
These events can be processed as follows:

1. Start in the empty state, and then call $sans("apply")(e_1)$, $sans("apply")(e_2)$, $sans("apply")(e_3)$, and $sans("apply")(e_4)$. This is valid because each event's parent version is the set of all events processed so far.
2. Before we can apply $e_5$ we must rewind the prepare version to be ${e_2}$, which is the parent of $e_5$. We can do this by calling $sans("retreat")(e_4)$ and $sans("retreat")(e_3)$.
3. Now we can call $sans("apply")(e_5)$, $sans("apply")(e_6)$, and $sans("apply")(e_7)$.
4. The parents of $e_8$ are ${e_4, e_7}$; before we can apply $e_8$ we must therefore add $e_3$ and $e_4$ back into the prepare state again. We do this by calling $sans("advance")(e_3)$ and $sans("advance")(e_4)$.
5. Finally, we can call $sans("apply")(e_8)$.

In complex event graphs such as the one in @topological-sort the same event may have to be retreated and advanced several times, but we can process arbitrary DAGs this way.
In general, before applying the next event $e$ in topologically sorted order, compute $G_"old" = sans("Events")(V_p)$ where $V_p$ is the current prepare version, and $G_"new" = sans("Events")(e.italic("parents"))$.
We then call $sans("retreat")$ on each event in $G_"old" - G_"new"$ (in reverse topological sort order), and call $sans("advance")$ on each event in $G_"new" - G_"old"$ (in topological sort order) before calling $sans("apply")(e)$.

The following algorithm efficiently computes the events to retreat and advance when moving the prepare version from $V_p$ to $V'_p$.
For each event in $V_p$ and $V'_p$ we insert the index of that event in the topological sort order into a priority queue, along with a tag indicating whether the event is in the old or the new prepare version.
We then repeatedly pop the event with the greatest index off the priority queue, and enqueue the indexes of its parents along with the same tag.
We stop the traversal when all entries in the priority queue are common ancestors of both $V_p$ and $V'_p$.
Any events that were traversed from only one of the versions need to be retreated or advanced respectively.

== Representing prepare and effect versions <prepare-effect-versions>

The internal state implements the $sans("apply")$, $sans("retreat")$, and $sans("advance")$ methods by maintaining a CRDT data structure.
This structure consists of a linear sequence of records, one per character in the document, including tombstones for deleted characters.
Runs of characters with consecutive IDs and the same properties can be run-length encoded to save memory.
A record is inserted into this sequence by $sans("apply")(e_i)$ for an insertion event $e_i$.
Subsequent deletion events and $sans("retreat")$/$sans("advance")$ calls may modify properties of the record, but records in the sequence are not removed or reordered once they have been inserted.

When the event graph contains concurrent insertion operations, we use an existing CRDT algorithm to ensure that all replicas place the records in this sequence in the same order, regardless of the order in which the event graph is traversed.
Any list CRDT could be used for this purpose; the main differences between algorithms are their performance and their interleaving characteristics @fugue.
Our implementation of #algname uses a variant of the Yjs algorithm @yjs @Nicolaescu2016YATA that we conjecture to be maximally non-interleaving; we leave a detailed analysis of this algorithm to future work, since it is not core to this paper.

Each record in this sequence contains:
- the ID of the event that inserted the character;
- $s_p in {mono("NotInsertedYet"), mono("Ins"), mono("Del 1"), mono("Del 2"), ...}$, the character's state in the prepare version;
- $s_e in {mono("Ins"), mono("Del")}$, the state in the effect version;
- and any other fields required by the CRDT to determine the order of concurrent insertions.

The rules for updating $s_p$ and $s_e$ are:

- When a record is first inserted by $sans("apply")(e_i)$ with an insertion event $e_i$, it is initialised with $s_p = s_e = mono("Ins")$.
- If $sans("apply")(e_d)$ is called with a deletion event $e_d$, we set $s_e = mono("Del")$ in the record representing the deleted character. In the same record, if $s_p = mono("Ins")$ we update it to $mono("Del 1")$, and if $s_p = mono("Del") n$ it advances to $mono("Del") (n+1)$, as shown in @spv-state.
- If $sans("retreat")(e_i)$ is called with insertion event $e_i$, we must have $s_p = mono("Ins")$ in the record affected by the event, and we update it to $s_p = mono("NotInsertedYet")$. Conversely, $sans("advance")(e_i)$ moves $s_p$ from $mono("NotInsertedYet")$ to $mono("Ins")$.
- If $sans("retreat")(e_d)$ is called with a deletion event $e_d$, we must have $s_p = mono("Del") n$ in the affected record, and we update it to $mono("Del") (n-1)$ if $n>1$, or to $mono("Ins")$ if $n=1$. Calling $sans("advance")(e_d)$ performs the opposite.

#figure(
  fletcher.diagram(spacing: (4mm, 4mm), node-stroke: 0.5pt, node-inset: 5mm,
  {
    let (nyi, ins, del1, del2, deln) = ((0, 0), (1, 0), (2, 0), (3, 0), (4, 0))
    node(nyi, `NIY`)
    node(ins, `Ins`)
    node(del1, `Del 1`)
    node(del2, `Del 2`)
    node(deln, $dots.c$, shape: "rect")

    node((-0.5, 0.8), [$sans("advance"):$], stroke: 0pt)
    node((0.5, 0.8), [$italic("Insert")$], stroke: 0pt)
    node((1.5, 0.8), [$italic("Delete")$], stroke: 0pt)
    node((2.5, 0.8), [$italic("Delete")$], stroke: 0pt)
    node((3.5, 0.8), [$italic("Delete")$], stroke: 0pt)
    edge(nyi, ins, bend: 50deg, "-|>")
    edge(ins, del1, bend: 50deg, "-|>")
    edge(del1, del2, bend: 50deg, "-|>")
    edge(del2, deln, bend: 50deg, "--|>")

    node((-0.5, -0.8), [$sans("retreat"):$], stroke: 0pt)
    node((0.5, -0.8), [$italic("Insert")$], stroke: 0pt)
    node((1.5, -0.8), [$italic("Delete")$], stroke: 0pt)
    node((2.5, -0.8), [$italic("Delete")$], stroke: 0pt)
    node((3.5, -0.8), [$italic("Delete")$], stroke: 0pt)
    edge(ins, nyi, bend: 50deg, "-|>")
    edge(del1, ins, bend: 50deg, "-|>")
    edge(del2, del1, bend: 50deg, "-|>")
    edge(deln, del2, bend: 50deg, "--|>")
  }),
  placement: top,
  caption: [State machine for internal state variable $s_p$.]
) <spv-state>

As a result, $s_p$ and $s_e$ are `Ins` if the character is visible (inserted but not deleted) in the prepare and effect version respectively; $s_p = mono("Del") n$ indicates that the character has been deleted by $n$ concurrent delete events in the prepare version; and $s_p = mono("NotInsertedYet")$ indicates that the insertion of the character has been retreated in the prepare version.
$s_e$ does not count the number of deletions and does not have a $mono("NotInsertedYet")$ state since we never remove the effect of an operation from the effect version.

#figure(
  fletcher.diagram(node-stroke: 0.5pt, node-inset: 5pt, spacing: 0pt,
    node((0,0), text(0.8em, [#v(5pt)$text("“H”")\ italic("id"): 3\ s_p: mono("Ins")\ s_e: mono("Ins")$]), shape: "rect"),
    node((1,0), text(0.8em, [#v(5pt)$text("“h”")\ italic("id"): 1\ s_p: mono("Del 1")\ s_e: mono("Del")$]), shape: "rect"),
    node((2,0), text(0.8em, [#v(5pt)$text("“i”")\ italic("id"): 2\ s_p: mono("Ins")\ s_e: mono("Ins")$]), shape: "rect"),
    node((3,0), box(width: 14mm, height: 0mm), stroke: 0pt),
    node((4,0), text(0.8em, [#v(5pt)$text("“H”")\ italic("id"): 3\ s_p: mono("NIY")\ s_e: mono("Ins")$]), shape: "rect"),
    node((5,0), text(0.8em, [#v(5pt)$text("“h”")\ italic("id"): 1\ s_p: mono("Ins")\ s_e: mono("Del")$]), shape: "rect"),
    node((6,0), text(0.8em, [#v(5pt)$text("“i”")\ italic("id"): 2\ s_p: mono("Ins")\ s_e: mono("Ins")$]), shape: "rect"),
    edge((2.6,0), (3.4,0), text(0.7em, $sans("retreat")(e_4)\ sans("retreat")(e_3)$), marks: "=>", thickness: 0.8pt, label-sep: 0.5em)
  ),
  placement: top,
  caption: [Left: the internal state after applying $e_1 ... e_4$ from @graph-hi-hey. Right: after $sans("retreat")(e_4)$ and $sans("retreat")(e_3)$, the prepare state is updated to mark "H" as `NotInsertedYet`, and the deletion of "h" is undone. The effect state is unchanged.]
) <crdt-state-1>

For example, @crdt-state-1 shows the state after applying $e_1 ... e_4$ from @graph-hi-hey, and how that state is updated by retreating $e_4$ and $e_3$ before $e_5$ is applied.
In the effect state, the lowercase "h" is marked as deleted, while the uppercase "H" and the "i" are visible.
In the prepare state, by retreating $e_4$ and $e_3$ the "H" is marked as `NotInsertedYet`, and the deletion of "h" is undone ($s_p = mono("Ins")$).

#figure(
  fletcher.diagram(node-stroke: 0.5pt, node-inset: 5pt, spacing: 0pt,
    node((0,0), text(0.8em, [#v(5pt)$text("“H”")\ italic("id"): 3\ s_p: mono("Ins")\ s_e: mono("Ins")$]), shape: "rect"),
    node((1,0), text(0.8em, [#v(5pt)$text("“h”")\ italic("id"): 1\ s_p: mono("Del 1")\ s_e: mono("Del")$]), shape: "rect"),
    node((2,0), text(0.8em, [#v(5pt)$text("“e”")\ italic("id"): 6\ s_p: mono("Ins")\ s_e: mono("Ins")$]), shape: "rect"),
    node((3,0), text(0.8em, [#v(3.5pt)$text("“y”")\ italic("id"): 7\ s_p: mono("Ins")\ s_e: mono("Ins")$]), shape: "rect"),
    node((4,0), text(0.8em, [#v(5pt)$text("“!”")\ italic("id"): 8\ s_p: mono("Ins")\ s_e: mono("Ins")$]), shape: "rect"),
    node((5,0), text(0.8em, [#v(5pt)$text("“i”")\ italic("id"): 2\ s_p: mono("Del 1")\ s_e: mono("Del")$]), shape: "rect")
  ),
  placement: top,
  caption: [The internal #algname state after replaying all of the events in @graph-hi-hey.]
) <crdt-state-2>

@crdt-state-2 shows the state after replaying all of the events in @graph-hi-hey: "i" is also deleted, the characters "e" and "y" are inserted immediately after the "h", $e_3$ and $e_4$ are advanced again, and finally the exclamation mark is inserted after the "y".
The figures include the character for the sake of readability, but the algorithm actually does not need to store characters in its internal state.

== Mapping indexes to character IDs

In the event graph, insertion and deletion operations specify the index at which they apply.
In order to update #algname's internal state, we need to map these indexes to the correct record in the sequence, based on the prepare state $s_p$.
To produce the transformed operations, we need to map the positions of these internal records back to indexes again -- this time based on the effect state $s_e$.

A simple but inefficient algorithm would be: to apply a $italic("Delete")(i)$ operation we iterate over the sequence of records and pick the $i$th record with a prepare state of $s_p = mono("Ins")$ (i.e., the $i$th among the characters that are visible in the prepare state, which is the document state in which the operation should be interpreted).
Similarly, to apply $italic("Insert")(i, c)$ we skip over $i - 1$ records with $s_p = mono("Ins")$ and insert the new record after the last skipped record (if there have been concurrent insertions at the same position, we may also need to skip over some records with $s_p = mono("NotInsertedYet")$, as determined by the list CRDT's insertion ordering).

To reduce the cost of this algorithm from $O(n)$ to $O(log n)$, where $n$ is the number of characters in the document, we construct a B-tree whose leaves, from left to right, contain the sequence of records representing characters.
We extend the tree into an _order statistic tree_ @CLRS2009 (also known as _ranked B-tree_) by adding two integers to each node: the number of records with $s_p = mono("Ins")$ contained within that subtree, and the number of records with $s_e = mono("Ins")$ in that subtree.
Every time $s_p$ or $s_e$ are updated, we also update those numbers on the path from the updated record to the root.
As the tree is balanced, this update takes $O(log n)$.

Now it is easy to find the $i$th record with $s_p = mono("Ins")$ in logarithmic time by starting at the root of the tree, and adding up the values in the subtrees that have been skipped.
Moreover, once we have a record in the sequence we can efficiently determine its index in the effect state by going in the opposite direction: working upwards in the tree towards the root, and summing the numbers of records with $s_e = mono("Ins")$ that lie in subtrees to the left of the starting record.
This allows us to efficiently transform the index of an operation from the prepare version into the effect version.
If the character was already deleted in the effect version ($s_e = mono("Del")$), the transformed operation is a no-op.

The above process makes $sans("apply")(e_i)$ efficient.
We also need to efficiently perform $sans("retreat")(e_i)$ and $sans("advance")(e_i)$, which modify the prepare state $s_p$ of the record inserted or deleted by $e_i$.
// For insert events, we modify the corresponding insert record with an _id_ of $i$, matching the event.
// And for delete events, we modify the record of the item _deleted by_ the event.
// Note that the event's index can't be used to locate the item, as the item's absolute position in the sequence may not match the event's index.
While advancing/retreating we cannot look up a target record by its index. Instead, we maintain a second B-tree, mapping from each event's ID to the target record. The mapping stores a value depending on the type of the event:

- For delete events, we store the ID of the character deleted by the event.
- For insert events, we store a pointer to the leaf node in the first B-tree which contains the corresponding record. When nodes in the first B-tree are split, we update the pointers in the second B-tree accordingly.

On every $sans("apply")(e)$, after updating the sequence as above, we update this mapping based on the event.
When we subsequently perform a $sans("retreat")(e)$ or $sans("advance")(e)$, that event $e$ must have already been applied, and hence $e.italic("id")$ must appear in this mapping.
This map allows us to advance or retreat in logarithmic time.

== Clearing the internal state <clearing>

As described so far, the algorithm retains every insertion since document creation forever in its internal state, consuming a lot of memory, and requiring the entire event graph to be replayed in order to restore the internal state.
We now introduce a further optimisation that allows #algname to completely discard its internal state from time to time, and replay only a subset of the event graph.

We define a version $V subset.eq G$ to be a _critical version_ in an event graph $G$ iff it partitions the graph into two subsets of events $G_1 = sans("Events")(V)$ and $G_2 = G - G_1$ such that all events in $G_1$ happened before all events in $G_2$:
$ forall e_1 in G_1: forall e_2 in G_2: e_1 -> e_2. $

Equivalently, $V$ is a critical version iff every event in the graph is either in $V$, or an ancestor of some event in $V$, or happened after _all_ of the events in $V$:
$ forall e_1 in G: e_1 in sans("Events")(V) or (forall e_2 in V: e_2 -> e_1). $
A critical version might not remain critical forever; it is possible for a critical version to become non-critical because a concurrent event is added to the graph.

A key insight in the design of #algname is that critical versions partition the event graph into sections that can be processed independently. Events that happened at or before a critical version do not affect how any event after the critical version is transformed. // #footnote[This property holds for our most, but not all text based CRDTs. Notably, this property does not hold for the Peritext CRDT for collaborative rich text editing @Litt2022peritext due to how peritext processes concurrent annotations.]
This observation enables two important optimisations:

- Any time the version of the event graph processed so far is critical, we can discard the internal state (including both B-trees and all $s_p$ and $s_e$ values), and replace it with a placeholder as explained in @partial-replay.
- If both an event's version and its parent version are critical versions, there is no need to traverse the B-trees and update the CRDT state, since we would immediately discard that state anyway. In this case, the transformed event is identical to the original event, so the event can simply be emitted as-is.

These optimisations make it very fast to process documents that are mostly edited sequentially (e.g., because the authors took turns and did not write concurrently, or because there is only a single author), since most of the event graph of such a document is a linear chain of critical versions.

The internal state can be discarded once replay is complete, although it is also possible to retain the internal state for transforming future events.
If a replica receives events that are concurrent with existing events in its graph, but the replica has already discarded its internal state resulting from those events, it needs to rebuild some of that state.
It can do this by identifying the most recent critical version that happened before the new event, replaying the existing events that happened after that critical version, and finally applying the new events.
Events from before that critical version are not replayed.
Since most editing histories have critical versions from time to time, this means that usually only a small subset of the event graph is replayed.
In the worst case, this algorithm replays the entire event graph.

== Partial event graph replay <partial-replay>

Assume that we want to add event $e_"new"$ to the event graph $G$, that $V_"curr" = sans("Version")(G)$ is the current document version reflecting all events except $e_"new"$, and that $V_"crit" eq.not V_"curr"$ is the latest critical version in $G union {e_"new"}$ that happened before both $e_"new"$ and $V_"curr"$.
Further assume that we have discarded the internal state, so the only information we have is the latest document state at $V_"curr"$ and the event graph; in particular, without replaying the entire event graph we do not know the document state at $V_"crit"$.

Luckily, the exact internal state at $V_"crit"$ is not needed. All we need is enough state to transform $e_"new"$ and rebase it onto the document at $V_"curr"$.
This internal state can be obtained by replaying the events since $V_"crit"$, that is, $G - sans("Events")(V_"crit")$, in topologically sorted order:

1. We initialise a new internal state corresponding to version $V_"crit"$. Since we do not know the the document state at this version, we start with a single placeholder record representing the unknown document content.
2. We update the internal state by replaying events from $V_"crit"$ to $V_"curr"$, but we do not output transformed operations during this stage.
3. Finally, we replay the new event $e_"new"$ and output the transformed operation. If we received a batch of new events, we replay them in topologically sorted order.

The placeholder record we start with in step 1 represents the range of indexes $[0, infinity]$ of the document state at $V_"crit"$ (we do not know the length of the document at that version, but we can still have a placeholder for arbitrarily many indexes).
Placeholders are counted as the number of characters they represent in the order statistic tree construction, and they have the same length in both the prepare and the effect versions.
We then apply events as follows:

- Applying an insertion at index $i$ creates a record with $s_p = s_e = mono("Ins")$ and the ID of the insertion event. We map the index to a record in the sequence using the prepare state as usual; if $i$ falls within a placeholder for range $[j, k]$, we split it into a placeholder for $[j, i-1]$, followed by the new record, followed by a placeholder for $[i, k]$. Placeholders for empty ranges are omitted.
- Applying a deletion at index $i$: if the deleted character was inserted prior to $V_"crit"$, the index must fall within a placeholder with some range $[j, k]$. We split it into a placeholder for $[j, i-1]$, followed by a new record with $s_p = mono("Del 1")$ and $s_e = mono("Del")$, followed by a placeholder for $[i+1, k]$. The new record has a placeholder ID that only needs to be unique within the local replica, and need not be consistent across replicas.
- Applying a deletion of a character inserted since $V_"crit"$ updates the record created by the insertion.

Before applying an event we retreat and advance as usual.
The algorithm never needs to retreat or advance an event that happened before $V_"crit"$, therefore every retreated or advanced event ID must exist in second B-tree.

If there are concurrent insertions at the same position, we invoke the CRDT algorithm to place them in a consistent order as discussed in @prepare-effect-versions.
Since all concurrent events must be after $V_"crit"$, they are included in the replay.
When we are seeking for the insertion position, we never need to seek past a placeholder, since the placeholder represents characters that were inserted before $V_"crit"$.

== Algorithm complexity <complexity>

Say we have two users who have been working offline, generating $k$ and $m$ events respectively.
When they come online and merge their event graphs, the latest critical version is immediately prior to the branching point.
If the branch of $k$ events comes first in the topological sort, the replay algorithm first applies $k$ events, then retreats $k$ events, applies $m$ events, and finally advances $k$ events again.
Asymptotically, $O(k+m)$ calls to apply/retreat/advance are required regardless of the order of traversal, although in practice the algorithm is faster if $k<m$ since we don't need to retreat/advance on the branch that is visited last.

Each apply/retreat/advance requires one or two traversals of first B-tree, and at most one traversal of the second B-tree.
The upper bound on the number of entries in each tree (including placeholders) is $2(k+m)+1$, since each event generates at most one new record and one placeholder split.
Since the trees are balanced, the cost of each traversal is $O(log(k+m))$.
Overall, the cost of merging branches with $k$ and $m$ events is therefore $O((k+m) log(k+m))$.

We can also give an upper bound on the complexity of replaying an event graph with $n$ events.
Each event is applied exactly once, and before each event we retreat or advance each prior event at most once, at $O(log n)$ cost.
The worst-case complexity of the algorithm is therefore $O(n^2 log n)$, but this case is unlikely to occur in practice.

== Storing the event graph <storage>

To store the event graph compactly on disk, we developed a compression technique that takes advantage of how people typically write text documents: namely, they tend to insert or delete consecutive sequences of characters, and less frequently hit backspace or move the cursor to a new location.
#algname's event graph storage format is inspired by the Automerge CRDT library @automerge-storage @automerge-columnar, which in turn uses ideas from column-oriented databases @Abadi2013 @Stonebraker2005. We also borrow some bit-packing tricks from the Yjs CRDT library @yjs.

We first topologically sort the events in the graph. Different replicas may sort the set differently, but locally to one replica we can identify an event by its index in this sorted order.
Then we store different properties of events in separate byte sequences called _columns_, which are then combined into one file with a simple header.
Each column stores some different fields of the event data. The columns are:

- _Event type, start position, and run length._ For example, "the first 23 events are insertions at consecutive indexes starting from index 0, the next 10 events are deletions at consecutive indexes starting from index 7," and so on. We encode this using a variable-length binary encoding of integers, which represents small numbers in one byte, larger numbers in two bytes, etc.
- _Inserted content._ An insertion event contains exactly one character (a Unicode scalar value), and a deletion does not. We simply concatenate the UTF-8 encoding of the characters for insertion events in the same order as they appear in the first column, and then LZ4-compress this string.
- _Parents._ By default we assume that every event has exactly one parent, namely its predecessor in the topological sort. Any events for which this is not true are listed explicitly, for example: "the first event has zero parents; the 153rd event has two parents, namely events numbers 31 and 152;" and so on.
- _Event IDs._ Each event is uniquely identified by a pair of a replica ID and a per-replica sequence number. This column stores runs of event IDs, for example: "the first 1085 events are from replica $A$, starting with sequence number 0; the next 595 events are from replica $B$, starting with sequence number 0;" and so on.

// TODO: the next two paragraphs could be omitted if we're short of space
We use several further tricks to reduce file size. For example, we run-length-encode deletions in reverse direction (due to holding down backspace). We express operation indexes relative to the end of the previous event, so that the number fits in fewer bytes. We deduplicate replica IDs, and so on.

We send the same data format over the network when replicating the entire event graph.
When sending a subset of events over the network (e.g., a single event during real-time collaboration), references to parent events outside of that subset need to be encoded using the $(italic("replicaID"), italic("seqNo"))$ event IDs, but otherwise a similar encoding can be used.

= Evaluation <benchmarking>

// Hints for writing systems papers https://irenezhang.net/blog/2021/06/05/hints.html
// Benchmarking crimes to avoid https://gernot-heiser.org/benchmarking-crimes.html

// TODO: anonymise the references to repos for the conference submission
// Can use a service like https://anonymous.4open.science/

In this work we compare #algname to various CRDT implementations and an OT implementation on 3 criteria:

/ Speed: The time taken to load a document and merge a set of changes from a remote peer.
/ Memory usage: The amount of RAM used to load a document and merge changes.
/ Storage size: The number of bytes needed to store or transmit the document's history.

We have found #algname to perform well on all of these measures. #algname merges complex editing traces at a similar speed as the equivalently constructed CRDT implementation. Peak memory usage (when merging complex changes) is higher than that of an equivalent CRDT, but after merging is complete, any memory used can be once again freed. And our binary encoding of the event graph takes up less space on disk.

Despite #algname merging complex changes at a speed similar to that of a CRDT, the CPU and memory profile of #algname can be quite different:

At startup time, #algname has no cost on the editing system. The document contents can simply be loaded from disk into memory. The event graph itself can stay on disk. The CRDT implementations we looked at work quite differently. When a document is opened, the CRDT state object is immediately unpacked from disk into a query-optimised data structure. This allows local events to be translated to the CRDT's message format. However, unpacking the CRDT state introduces latency at load time and increases the memory footprint of the process.

When concurrent events are merged together, #algname constructs a new CRDT state object from the most recent common version of the merged branches. This state object is used to transform the merged events. After transformation, the state object can be discarded. The CRDT implementations we looked at allocate memory at startup for their CRDT state objects and retain that memory throughout the editing session. #algname does not need memory at startup, but will consume significant amounts of temporary memory when merging complex sets of concurrent changes.

As a result, #algname allows documents to be loaded from disk and edited much faster than CRDTs allow, and with less resident memory usage. When changes are merged, the CRDT state is only reconstructed back to the common branching point, so merging sequential changes, or recent concurrent changes is consistently fast. The slowest operation #algname encounters is when it merges large, long lived branches together. When this happens, memory usage temporarily spikes as events are loaded from disk, and transformed via a temporary CRDT state object.

// TODO: Move this further down I reckon.
// CRDTs have extra overhead when a document is loaded because CRDTs require local editing events to be translated into the corresponding CRDT messages before they can be saved to disk or broadcast to remote peers. In order to translate editing events into CRDT messages, a local replica needs to query the current CRDT state object. In the systems we looked at, each time a document is opened, the CRDT state must be unpacked into a query-optimised data structure in RAM before any edits can take place. This introduces noticeable latency at startup time, and

// When necessary, #algname also reconstructs this state. However, #algname only needs to build this state object in memory when merging concurrent changes. And even then, the state is only reconstructed as far back as the most recent common version. Once merging is complete, #algname can immediately discard this state object from memory.

// In our testing we have found the _worst case_ performance for #algname is similar to the _expected_ performance when using a similar CRDT library. The best case performance of #algname is significantly faster than that of an equivalent CRDT.

#figure(
  text(8pt, table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    stroke: (x, y) => (
      left: if x == 1 { 0.4pt } else { none },
      // right: none,
      // top: if y == 0 { 0.8pt } else { none },
      // bottom: none,
    ),
    table.hline(stroke: 0.8pt),
    // table.header([Work performed when \\ by], [*OT*], [*#algname*], [*CRDT*]),
    table.header([],
      [*OT*],
      [*CRDT*],
      [*#algname* (ours)],
    ),
    table.hline(stroke: 0.4pt),
    [Merge time (ms)],
      [#calc.round(charts.avg_times.ot, digits: 0)],
      [#calc.round(charts.avg_times.dtcrdt, digits: 1)],
      [*#calc.round(charts.avg_times.dt, digits: 1)*],
    [Load time (ms)],
      [*#calc.round(charts.avg_opt_load_time, digits: 2)*],
      [#calc.round(charts.avg_times.dtcrdt, digits: 1)],
      [*#calc.round(charts.avg_opt_load_time, digits: 2)*],
    [Memory usage (peak MB)],
      [#calc.round(charts.avg_mem.ot.peak / 1e6, digits: 1)],
      [*#calc.round(charts.avg_mem.dtcrdt.peak / 1e6, digits: 1)*],
      [#calc.round(charts.avg_mem.dt.peak / 1e6, digits: 1)],
    [Memory usage (steady MB)],
      [*#calc.round(charts.avg_mem.ot.steady_state / 1e6, digits: 2)*],
      [#calc.round(charts.avg_mem.dtcrdt.steady_state / 1e6, digits: 1)],
      [*#calc.round(charts.avg_mem.dt.steady_state / 1e6, digits: 2)*],
    table.hline(stroke: 0.8pt),
  )),
  placement: top,
  caption: [
    Summary of average CPU and memory usage results. This table shows the time taken (in milliseconds) and heap memory used (peak and at quiescence) for our OT, reference CRDT and optimised #algname implementations. In this table we show the mean result across all of our editing traces.
  ]
) <work-table>

== Implementations

We created two implementations of #algname: a reference implementation optimised for simplicity and readability written in Typescript @reference-reg, and a production-ready, performance optimised implementation written in Rust @dt.
Our reference implementation omits several important optimisations, including internal run-length encoding, B-trees and event graph sorting.
All benchmarks in this section use our performance optimised version of #algname.

We have benchmarked #algname against two popular CRDT libraries: Automerge @automerge and Yjs#footnote[We also tested Yrs @yrs, the Rust rewrite of Yjs by the original authors. At the time of writing it performs worse than Yjs, so we have omitted it from our results.] @yjs. However, these libraries exhibit a large range of performance. In an effort to remove the effect of implementation differences in our results, we have also implemented our own performance-optimised reference CRDT library. This library shares most of its code with our optimised #algname implementation, making for (as much as possible) a like-to-like performance comparison between approaches. Our reference CRDT library outperforms both Yjs and Automerge.

For comparison, we have also implemented a simple Operational Transform implementation. This OT library batch transforms operations in a given event graph. Intermediate transformed operations are memoized and reused during the graph traversal - which dramatically improves performance but also increases memory usage. This library has not been optimised as thoroughly as the other code.

All code and data used in our benchmarks is published alongside this article.
Details of the hardware and software setup used in our experiments is given in @benchmark-setup.


== Editing traces

// TODO: add node_nodecc and git-makefile to editing-traces repo
// TODO: anonymise the editing-traces repo for the conference submission

In order to ensure our benchmarks are meaningful, we collected a dataset of text editing traces from real documents, which we have made freely available on GitHub @editing-traces.
The traces we use are listed in @traces-table.
There are three types:

#let stats_for(name, type) = {
  let data = json("results/dataset_stats.json").at(name)
  (
    name,
    type,
    str(calc.round(data.total_keystrokes / 1000, digits: 1)),
    str(calc.round(data.concurrency_estimate, digits: 2)),
    str(data.graph_rle_size),
    str(data.num_agents)
  )
}

#figure(
  text(8pt, table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (center, center, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Name*], [*Type*], [*Events (k)*], [*Conc*], [*Runs*], [*Replicas*]),
    table.hline(stroke: 0.4pt),

    ..stats_for("S1", "seq"),
    ..stats_for("S2", "seq"),
    ..stats_for("S3", "seq"),
    ..stats_for("C1", "conc"),
    ..stats_for("C2", "conc"),
    ..stats_for("A1", "async"),
    ..stats_for("A2", "async"),
    table.hline(stroke: 0.8pt),
  )),
  placement: top,
  caption: [
    The text editing traces used in our evaluation. _Events_: total number of editing events, in thousands. Each inserted or deleted character counts as 1 event. _Average concurrency_: mean number of concurrent branches per event in the trace. _Runs_: number of sequential runs (linear event sequences without branching/merging). _Replicas_: number of users who added at least one event.
  ]
) <traces-table>

/ Sequential Traces: (S1, S2, S3): Keystroke-granularity history of a single user writing a document, collected using an instrumented text editor. These traces contain no concurrency. We use the LaTeX source of a journal paper @Kleppmann2017 @automerge-perf, the text of an 8,800-word blog post @crdts-go-brrr, and the source for this article.
/ Concurrent Traces: (C1, C2): Multiple users concurrently editing the same document in realtime, recorded with keystroke granularity. We added 0.5–1 second of artificial latency between the collaborating users to increase the incidence of concurrent operations.
/ Asynchronous Traces: (A1, A2): We reconstructed the editing trace of some files in Git repositories. The event graph mirrors the branching/merging of Git commits. Since Git does not record individual keystrokes, we generated the minimal edit operations necessary to perform each commit's diff. We use `src/node.cc` from the Git repository for Node.js @node-src-nodecc and `Makefile` from the Git repository for Git itself @git-makefile.

The recorded editing traces originally varied a great deal in size. We have roughly standardised the sizes of all editing traces by duplicating the recorded event graphs multiple times in our data files. For example, a trace containing events ${A, B, C, ...}$ would be repeated to become ${A_1, B_1, C_1, ..., A_2, B_2, C_2, ..., A_3, B_3, C_3, ...}$. Each repeated copy of the graph happens causally after all earlier repetitions, so for example ${A_1, B_1, C_1, ...} -> {A_2, ...} -> {A_3, ...}$. All traces have been normalised this way to contain approximately 500k inserted characters. If printed, the resulting documents would be up to about 100 pages in length, depending on the number of deleted characters and the printed font size.


== Time taken to load and merge changes

// We have measured the time taken to merge our editing traces into a local, empty document. Once all events were loaded, the document was saved and loaded back.

The slowest operation a collaborative editing system performs is merging a large set of remote editing events from another peer. All received changes need to be transformed and merged into the active document. @chart-remote shows the time taken by each tested algorithm to merge all changes in our dataset into an empty document. For the CRDT implementations, all events were preprocessed into the appropriate CRDT message format. The time taken to do this is not included in our measurements.

Once all events were received from a remote peer, the resulting local state was saved to disk and then loaded back into memory. The CRDT implementations execute the same commands to construct a local CRDT object from remote events and from events stored on disk. OT and #algname based systems are able to simply load the resulting text content directly from disk. When using one of these approaches, historical events are only loaded from disk when concurrent branches are merged together.

For completeness, we also measured the time taken to process local editing events. However, all of the systems we tested can process events many orders of magnitude much faster than any human's typing speed. We have not shown this data as at that speed, the differences between systems are irrelevant.

#figure(
  text(8pt, [
    #charts.speed_merge
    // #charts.speed_load
  ]),
  caption: [
    The time taken by each algorithm to merge all editing events and reload the resulting document from disk. Each algorithm received as input the complete set of "remote events" (which differed depending on the algorithm) and output the resulting, merged document. The CRDT implementations (Ref CRDT, Automerge and Yjs) take the same amount of time to merge changes as they do to subsequently load the document from disk. The red line in this chart shows 1 frame \@ 60hz.
  ],
  kind: image,
  placement: top,
) <chart-remote>

The merge times are interesting for several reasons:
// And I'm not sure how many of these reasons to include here!

// - #algname and the OT implementation, as expected, added no overhead at all in processing the purely sequential event traces (S1, S2, S3).
- When merging, there is more difference between different CRDT implementations than there is between #algname and our reference CRDT implementation. When measuring pure performance, implementation quality seems to matter more than algorithm.
- C1 and C2 hit some pathological case in the automerge library. We have reported this to the package maintainers.
- As expected, our operational transform implementation performs very well when there is no concurrency. But it scales very poorly as editing traces become more complex. Merging the _A2_ trace took approximately 1 hour - which is 160 000x slower than #algname.


== #algname performance and concurrency

In @chart-remote above, we see that #algname is especially fast on traces that are mostly or entirely sequential (e.g., _A1_ and _S1_, respectively).
This is because #algname can clear its internal state and skip all of the internal state manipulation on critical versions (@clearing).
To quantify this effect, we compare #algname's performance with a version of the algorithm that has these optimisations disabled.
@ff-memory shows the memory usage over the course of replaying one trace, and @speed-ff shows the time taken to replay all our traces with this optimisation enabled and disabled.

// TODO: what is the unit ("state size") of the y axis of this chart?
// TODO: Typst has a bug that is currently labelling this figure with the wrong number!
#figure(
  text(8pt, charts.ff_chart),
  caption: [
    A comparison of the #algname state size while processing the _raw C1_ data set, with and without internal state clearing enabled. This chart uses the raw (not duplicated) version of the dataset.
  ],
  kind: image,
  placement: top,
) <ff-memory>

// TODO: This chart does not include time spent *applying* the transformed changes, so its slightly faster
// than the merge times we list.
#figure(
  text(8pt, charts.speed_ff),
  caption: [
    Time taken for #algname to transform all events in an event graph, with and without the optimisations from @clearing.
  ],
  kind: image,
  placement: top,
) <speed-ff>

The _A2_ editing trace does not contain any critical events, so performance is the same as if the optimisations are disabled, whereas the fully sequential editing traces are processed approximately 15$times$ faster with these optimisations.
The concurrent trace used in @ff-memory has frequently occurring critical versions, allowing the optimisation to keep the internal state small.

When processing an event graph with very high concurrency (like _git-makefile_), the performance of #algname is highly dependent on the order in which events are traversed.
A poorly chosen traversal order can make this test as much as 8$times$ slower, and our topological sort algorithm (@graph-walk) tries to avoid such pathological cases.
However, the topological sort itself also takes time: in the _friendsforever_ and _clownschool_ traces, about 40% of the runtime is the topological sort, as there are thousands of tiny branch and merge points due to the fine-grained concurrency.

/*
#figure(
  text(8pt, charts.all_speed_local),
  caption: [
    xxx
    // Comparative speed of DT and DT-crdt algorithms processing remote data, measured in millions of run-length encoded events processed per second.
  ],
  kind: image,
  placement: top,
) <chart-all-local>
*/


== RAM usage

In @chart-memusage we show the memory footprint (retained heap size) of each algorithm. The memory used by #algname and OT is split into peak usage (during merge operations) and the "steady state" memory usage, after temporary data is discarded and the system has returned to quiescence.

The OT implementation used here memoizes intermediate transformed operations to improve performance. However, keeping this the memoized data in memory results in dramatically higher memory usage. At peak this implementation used 6.8GB of RAM to merge the _A2_ editing trace.

The computer we used for benchmarking had enough RAM to prevent swapping in all cases.

#figure(
  text(7pt, charts.memusage_all),
  caption: [
    RAM used while replaying all editing traces. The #algname and OT algorithms only need additional RAM while merging concurrent changes. Once all changes are merged, only the current document text is retained.
  ],
  kind: image,
  placement: top,
) <chart-memusage>


== Storage size

Our binary encoding of event graphs (@storage) results in smaller files than the equivalent internal CRDT state persisted by Automerge or Yjs.
To ensure a like-for-like comparison we have disabled #algname's built-in LZ4 and Automerge's built-in gzip compression. Enabling this compression further reduces the file sizes.

// TODO: instead of disabling compression in Automerge and DT, maybe it would be better to report the gzipped file size for all libraries? That will not change the Automerge/DT file size much, but it will reduce the Yjs file size to make a fair comparison.
// (seph): No, that causes problems because of the repeated event graphs. Gzip is (sometimes) clever enough to compact the repeated events - but thats very algorithm dependant.


Automerge also stores the full editing history of a document, and @chart-dt-vs-automerge shows the resulting file sizes relative to the raw concatenated text content of all insertions.
In all of our traces, #algname has a significantly smaller file size, and the graph structure adds only modest overhead to the raw text.

// TODO: Is this worth adding?
// Note that storing the raw editing trace in this compact form removes one of the principle benefits of #algname, as the event graph must be replayed in order to determine the current document text. To improve load time, the current text content can be cached and stored alongside the event graph on disk. Alternately, the transformed operation positions can also be stored in the file. In our testing, this resulted in a tiny increase in file size while improving load performance by an order of magnitude.

In contrast, Yjs does not store any deleted characters. This results in a smaller file size, at the cost of not being able to reconstruct past document states.
To make the comparison fair, @chart-dt-vs-yjs compares Yjs to a variant of our event graph encoding in which the text content of deleted characters is omitted.
Our encoding is smaller than Yjs on all traces, and the overhead of storing the event graph is between 20% and 3$times$ the final plain text file size.

// TODO: why is git-makefile not included in this and the following figure?
#figure(
  text(8pt, charts.filesize_full),
  caption: [Relative file size storing edit traces using #algname's event graph encoding and Automerge. The lightly shaded region in each bar shows the concatenated length of all inserted text - which is a lower bound on the file size in this test.],
  kind: image,
  placement: top,
) <chart-dt-vs-automerge>

#figure(
  text(8pt, charts.filesize_smol),
  caption: [File size of our event graph encoding in which deleted text content has been omitted, compared to the equivalent Yjs file size. The lightly shaded region is the size of the resulting document, which acts as a lower bound on the file size.],
  kind: image,
  placement: top,
) <chart-dt-vs-yjs>




= Related Work <related-work>

#algname is an example of a _pure operation-based CRDT_ @polog, which is a family of algorithms that capture a DAG (or partially ordered log) of operations in the form they were generated, and define the current state as a query over that log.
However, existing publications on pure operation-based CRDTs @Almeida2023 @Bauwens2023 present only datatypes such as maps, sets, and registers; #algname adds a list/text datatype to this family.

MRDTs @Soundarapandian2022 are similarly based on a DAG, and use a three-way merge function to combine two branches since their lowest common ancestor; if the LCA is not unique, a recursive merge is used.
MRDTs for various datatypes have been defined, but so far none offers text with arbitrary insertion and deletion.

Toomim's _time machines_ approach @time-machines shares a conceptual foundation with #algname: both are based on traversing an event graph, with operations being transformed from the form in which they were originally generated into a form that can be applied in topologically sorted order to obtain the current document state.
Toomim also points out that CRDTs can be used to perform this transformation.
#algname is a concrete, optimised implementation of the time machine approach; novel contributions of #algname include updating the prepare version by retreating and advancing, as well as the details of partial event graph replay.

#algname can also be regarded as an _operational transformation_ (OT) algorithm @Ellis1989, since it takes operations that insert or delete characters at some index, and transforms them into operations that can be applied to the local replica state to have an effect equivalent to the original operation in the state in which it was generated.
OT has a long lineage of research, tracing back to several seminal papers in the 1990s @Nichols1995 @Ressel1996 @Sun1998.
To our knowledge, all existing OT algorithms follow a pattern of two sub-algorithms: a set of _transformation functions_ that transform one operation with regard to one other, concurrent operation, and a _control algorithm_ that traverses an editing history and invokes the necessary transformation functions.
A problem with this architecture is that when two replicas have diverged and each performed $n$ operations, merging their states unavoidably has a cost of at least $O(n^2)$, as each operation from one branch needs to be transformed with respect to all of the operations on the other branch; in some OT algorithms the cost is cubic or even worse @Li2006 @Roh2011RGA @Sun2020OT.
#algname departs from the transformation function/control algorithm architecture and instead performs transformations using an internal CRDT state, which reduces the merging cost to $O(n log n)$ in most cases; the theoretical upper bound of $O(n^2 log n)$ is unlikely to occur in practical editing histories.

Moreover, most practical implementations of OT require a central server to impose a total order on operations.
Although it is possible to perform OT in a peer-to-peer context without a central server @Sun2020OT, several early published peer-to-peer OT algorithms later turned out to be flawed @Imine2003 @Oster2006TTF, leaving OT with a reputation of being difficult to reason about @Levien2016.
We have not formally evaluated the ease of understanding #algname, but we believe that it is easier to establish the correctness of our approach compared to distributed OT algorithms.

Other prominent collaborative text editing algorithms belong to the _conflict-free replicated data types_ (CRDTs) family @Shapiro2011, with early examples including RGA @Roh2011RGA, Treedoc @Preguica2009, and Logoot @Weiss2010, and Fugue @fugue being more recent.
To our knowledge, all existing CRDTs for text work by assigning every character a unique ID, and translating index-based insertions and deletions into ID-based addressing.
These unique IDs need to be persisted for the lifetime of the document and sent to all replicas, increasing I/O costs, and they need to be held in memory when a document is being edited, causing memory overhead.
In contrast, #algname uses unique IDs only transiently during replay but does not persist or replicate them, and it can free all of its internal state whenever a critical version is reached.
#algname does need to store the event graph as long as concurrent operations may arrive, but this takes less space than CRDT metadata, and it only needs to be memory-resident to handle concurrent operations; most of the time the event graph can remain on disk.

Gu et al.'s _mark & retrace_ method @Gu2005 is superficially similar to #algname, but it differs in several important details: it builds a CRDT-like structure containing the entire editing history, not only the parts being merged, and its ordering of concurrent insertions is prone to interleaving.

Version control systems such as Git, as well as differential synchronization @Fraser2009, perform merges by diffing the old and new states on one branch, and applying the diff to the other branch.
Applying patches relies on heuristics, such as searching for some amount of context before and after the modified text passage, which can apply the patch in the wrong place if the same context exists in multiple locations, and which can fail if the context has concurrently been modified.
These approaches therefore generally require manual merge conflict resolution and don't ensure automatic replica convergence.


= Conclusion

#algname is a new approach to collaborative text editing that has significant performance advantages over existing OT and CRDT algorithms.
Compared to CRDTs, it uses less memory, files are smaller and faster to load, and edits from other users are merged much faster in documents with largely sequential editing.
Compared to OT, large merges (e.g., from users who did a significant amount of work while offline) are much faster, both asymptotically and in practice, and peer-to-peer collaboration is robustly supported.

Moreover, since #algname stores the full keystroke-granularity editing history of a document, it allows applications to show that history to the user, and to restore arbitrary past versions of a document.
The only downsides we have found with #algname is that it is more complex to implement, and it is somewhat slower than an optimised CRDT on event graphs with a high degree of concurrency (though easily fast enough for practical use, with merging throughput of over 1 million events/sec).

The underlying event graph is a straightforward representation of the edits that have occurred, which is easy to replicate over any network, and which is not specific to the #algname algorithm.
We therefore expect that the same data format will be able to support future collaborative editing algorithms as well, without requiring the data format to be changed.
We also believe that #algname can be extended to other file types such as rich text, graphics, or spreadsheets, and we believe that this is a promising direction for future research in realtime editing.

#if not anonymous [
  #heading(numbering: none, [Acknowledgements])

  This work was made possible by the generous support from Michael Toomim, the Braid community and the Invisible College. None of this would have been possible without financial support and the endless conversations we have shared about collaborative editing.
  Thank you to Matthew Weidner and Joe Hellerstein for feedback on a draft of this paper.
]

#show bibliography: set text(8pt)
#bibliography(("works.yml", "works.bib"),
  title: "References",
  style: "association-for-computing-machinery"
)

#counter(heading).update(0)
#set heading(numbering: "A", supplement: "Appendix")

/*
= Generic CRDT to replay algorithm <generic-crdt-replay>

In this section, we present a generic replay function which matches the behaviour of any CRDT.

This algorithm is presented in Haskell. In other programming languages, this algorithm would need to actively memoize some function return values to prevent exponential time complexity. In @am-converter we present an equivalent algorithm in Rust, presented using Automerge@automerge to replay sequence editing events - though the algorithm could easily be adapted to use any event source and compatible CRDT.

Given the CRDT is defined by the following set of methods:

#code(
  block-align: none,
  row-gutter: 3pt,
  fill: none,
  // indent-guides: 1pt + gray,
  // column-gutter: 5pt,
  // inset: 5pt,
  // stroke: 2pt + black,
  // stroke: none,
)[
  ```haskell
  initialState :: CRDT
  query :: CRDT -> Doc

  -- Modify a CRDT by applying a local update.
  update :: (CRDT, (Id, Event)) -> CRDT

  -- Statefully merge 2 CRDTs. Merge must be commutative and idempotent.
  merge :: (CRDT, CRDT) -> CRDT

  mergeAll :: [CRDT] -> CRDT
  mergeAll crdts = foldl initialState crdts
  ```
]

The replay function then can be defined recursively like this:

#code(
  block-align: none,
  row-gutter: 3pt,
  fill: none,
  // indent-guides: 1pt + gray,
  // column-gutter: 5pt,
  // inset: 5pt,
  // stroke: 2pt + black,
  // stroke: none,
)[
```haskell
-- Given some helper functions for accessing events:
lookup :: Graph -> Id -> (Event, [Id])
allIds :: Graph -> [Id]

emptyDoc :: Doc
emptyDoc = query initialState

-- Get the CRDT's state immediately after any event
crdtAfterEvent :: Graph -> Id -> CRDT
crdtAfterEvent graph, id = update crdtBeforeEvent event
  where
    (event, parentIds) = lookup graph id
    crdtBeforeEvent = replay graph parentIds

-- Replay the transitive subset of the graph named by version [Id]
replay :: Graph -> [Id] -> CRDT
replay graph, ids = mergeAll (map (crdtAfterEvent graph) ids)

replayAll :: Graph
replayAll graph = replay graph (allIds graph)
```
]

// CLAIM: Using an event graph, in combination with this replay function ($q$ = *replayAll*), this algorithm will generate the same document state at all times to the equivalent CRDT.

*/

= Benchmark Setup <benchmark-setup>

All benchmarks were run on a Ryzen 7950x CPU running Linux 6.5.0-28 and 64GB of RAM. (Enough to prevent memory swapping in all cases).

Rust code was compiled with `rustc v1.77.2` and compiled in release mode with `-C target-cpu=native`. Code is run on a single, pinned core for consistency.

Javascript was run using `nodejs v21.7.0`.

All time based measurements are based on the mean of at least 100 test iterations except OT running A2. This test was only run for 10 iterations. Error bars are not included above as the standard deviation for all benchmark results was less than 1%.

All benchmark code and data is available on Github. We tested the following versions of all libraries:

#table(
  columns: (auto, auto, auto),
  align: (left, left, right, right, right, right),
  [*Library*], [*Language*], [*Version / Git Hash*],
  [Diamond Types (DT / DT-CRDT)], [Rust], [`44a65c44bf`],
  [Automerge], [Rust], [v 0.5.9],
  [Yjs], [Javascript], [v 13.6.10],
  // [JSON-Joy], [Javascript], [`38392b30228a`],
  // [Cola], [Rust], [v 0.1.1],
)

Cola with cursor optimisation removed is available at `https://github.com/josephg/cola-nocursors/`. //#link(https://github.com/josephg/cola-nocursors/).

= Proof of Correctness <proofs>

TODO

// "given an event to be added to an existing event graph, return the (index-based) operation that must be applied to the current document state so that the resulting document is identical to replaying the entire event graph including the new event" (end of Section 2)