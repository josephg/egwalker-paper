// #import "@preview/cetz:0.1.2": canvas, plot, draw
// #import "@preview/fletcher:0.2.0" as fletcher: node, edge
#import "@preview/fletcher:0.3.0" as fletcher: node, edge
#import "@preview/ctheorems:1.1.2": *
#import "@preview/algo:0.3.3": algo, i, d, comment, code
// #import "@preview/lovelace:0.1.0": *
#import "@preview/algorithmic:0.1.0": algorithm
#import "@preview/cetz:0.1.2"
#import "charts.typ"
#show: thmrules.with(qed-symbol: $square$)

// Might be worth pulling these two fields in from a config file instead
#let anonymous = true
#let draft = true


#let algname = "Eg-walker"
#if anonymous {
  algname = "Feathertail"
}

#let background = none
#if draft {
  background = rotate(64deg, text(120pt, fill: rgb("DFDBD4"))[*DRAFT*])
}

#set page(
  paper: "a4",
  numbering: "1",
  // 178 × 229 mm text block on an A4 page (210 × 297 mm)
  margin: (x: (210 - 178) / 2 * 1mm, y: (297 - 229) / 2 * 1mm),
  background: background
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

#let theorem = thmplain("theorem", "Theorem", base_level: 0, titlefmt: strong).with(inset: 0pt)
#let lemma = thmplain("theorem", "Lemma", base_level: 0, titlefmt: strong).with(inset: 0pt)
#let proof = thmproof("proof", "Proof").with(inset: 0pt)

#if draft {
  align(center, text(16pt)[
    Draft #datetime.today().display()
  ])
}

#if anonymous {
  align(center, text(20pt)[*Fast and memory-efficient collaborative text editing*])
  align(center, text(12pt)[
    Anonymous Author(s) \
    Submission ID: 223
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
Unfortunately, these IDs need to be held in memory while a document is being edited.
Even with careful optimisation, this metadata uses more than 10 times as much memory as the document text, and makes documents much slower to load from disk.
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
- We prove the correctness of #algname in @proofs. // TODO!

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

== Event graphs <event-graphs>

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
For all valid event graphs $G$, $sans("Events")(sans("Version")(G)) = G$.

The set of parents of an event in the graph is the version of the document in which that operation must be interpreted.
The version can hence be seen as a _logical clock_, describing the point in time at which a replica knows about the exact set of events in $G$.
Even if the event graph is large, in practice a version rarely consists of more than two events.

== Replaying editing history <replay>

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
While OT transforms one operation with respect to one other, #algname uses the internal state to transform operations efficiently.

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

For example, the graph in @graph-example has two possible sort orders; #algname either first inserts "l" at index 3 and then "!" at index 5 (like User 1 in @two-inserts), or it first inserts "!" at index 4 followed by "l" at index 3 (like User 2 in @two-inserts). The final document state is "Hello!" either way.

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
This uses significant amounts of memory and makes documents slow to load.

OT algorithms avoid this internal state; similarly to #algname, they only need to persist the latest document state and the history of operations that are concurrent to operations that may arrive in the future.
In both #algname and OT, the event graph can be discarded if we know that no event we may receive in the future will be concurrent with any existing event.
However, OT algorithms are very slow to merge long-running branches (see @benchmarking).
Some OT algorithms are only able to handle restricted forms of event graphs, whereas #algname handles arbitrary DAGs.

== Walking the event graph <graph-walk>

For the sake of clarity we first explain a simplified version of #algname that replays the entire event graph without discarding its internal state along the way. This approach incurs some CRDT overhead even for non-concurrent operations.
In @partial-replay we show how the algorithm can be optimised to replay only a part of the event graph.

First, we topologically sort the event graph in a way that keeps events on the same branch consecutive as much as possible: for example, in @topological-sort we first visit $e_"A1" ... e_"A4"$, then $e_"B1" ... e_"B4"$. We avoid alternating between branches, such as $e_"A1", e_"B1", e_"A2", e_"B2" ...$, even though that would also be a valid topological sort.
For this we use a standard textbook algorithm @CLRS2009: perform a depth-first traversal starting from the oldest event, and build up the topologically sorted list in the order that events are visited.
When a node has multiple children in the graph, we choose their order based on a heuristic so that branches with fewer events tend to appear before branches with more events in the sorted order; this can improve performance (see @complexity) but is not essential.
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
4. The parents of $e_8$ are ${e_4, e_7}$; before we can apply $e_8$ we must therefore add $e_3$ and $e_4$ to the prepare state again by calling $sans("advance")(e_3)$ and $sans("advance")(e_4)$.
5. Finally, we can call $sans("apply")(e_8)$.

In complex event graphs such as the one in @topological-sort the same event may have to be retreated and advanced several times, but we can process arbitrary DAGs this way.
In general, before applying the next event $e$ in topologically sorted order, compute $G_"old" = sans("Events")(V_p)$ where $V_p$ is the current prepare version, and $G_"new" = sans("Events")(e.italic("parents"))$.
We then call $sans("retreat")$ on each event in $G_"old" - G_"new"$ (in reverse topological sort order), and call $sans("advance")$ on each event in $G_"new" - G_"old"$ (in topological sort order) before calling $sans("apply")(e)$.

/*
The following algorithm efficiently computes the events to retreat and advance when moving the prepare version from $V_p$ to $V'_p$.
For each event in $V_p$ and $V'_p$ we insert the index of that event in the topological sort order into a priority queue, along with a tag indicating whether the event is in the old or the new prepare version.
We then repeatedly pop the event with the greatest index off the priority queue, and enqueue the indexes of its parents along with the same tag.
We stop the traversal when all entries in the priority queue are common ancestors of both $V_p$ and $V'_p$.
Any events that were traversed from only one of the versions need to be retreated or advanced respectively.
*/

== Representing prepare and effect versions <prepare-effect-versions>

The internal state implements the $sans("apply")$, $sans("retreat")$, and $sans("advance")$ methods by maintaining a CRDT data structure.
This structure consists of a linear sequence of records, one per character in the document, including tombstones for deleted characters.
Runs of characters with consecutive IDs and the same properties can be run-length encoded to save memory.
A record is inserted into this sequence by $sans("apply")(e_i)$ for an insertion event $e_i$.
Subsequent deletion events and $sans("retreat")$/$sans("advance")$ calls may modify properties of the record, but records in the sequence are not removed or reordered once they have been inserted.

When the event graph contains concurrent insertions, we use a CRDT to ensure that all replicas place the records in this sequence in the same order, regardless of the order in which the event graph is traversed.
For example, RGA @Roh2011RGA or YATA @Nicolaescu2016YATA could be used for this purpose.
Our implementation of #algname uses a variant of the Yjs algorithm @yjs, itself based on YATA, that we conjecture to be maximally non-interleaving.
We leave a detailed analysis of this algorithm to future work, since it is not core to this paper.

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

@crdt-state-2 shows the state after replaying all of the events in @graph-hi-hey: "i" is also deleted, the characters "e" and "y" are inserted immediately after the "h", $e_3$ and $e_4$ are advanced again, and finally "!" is inserted after the "y".
The figures include the character for the sake of readability, but #algname actually does not store text content in its internal state.

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
- For insert events, we store a pointer to the leaf node in the first B-tree that contains the corresponding record. When nodes in the first B-tree are split, we update the pointers in the second B-tree accordingly.

On every $sans("apply")(e)$, after updating the sequence as above, we update this mapping.
When we subsequently call $sans("retreat")(e)$ or $sans("advance")(e)$, that event $e$ must have already been applied, and hence $e.italic("id")$ must appear in this mapping.
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
It can do this by identifying the most recent critical version that happened before the new events, replaying the existing events that happened after that critical version, and finally applying the new events.
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
3. Finally, we apply the new event $e_"new"$ and output the transformed operation. If we received a batch of new events, we apply them in topologically sorted order.

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

We first topologically sort the events in the graph. Different replicas may sort the graph differently, but locally to one replica we can identify an event by its index in this sorted order.
Then we store different properties of events in separate byte sequences called _columns_, which are then combined into one file with a simple header.
Each column stores some different fields of the event data. The columns are:

- _Event type, start position, and run length._ For example, "the first 23 events are insertions at consecutive indexes starting from index 0, the next 10 events are deletions at consecutive indexes starting from index 7," and so on. We encode this using a variable-length binary encoding of integers, which represents small numbers in one byte, larger numbers in two bytes, etc.
- _Inserted content._ An insertion event contains exactly one character (a Unicode scalar value), and a deletion does not. We concatenate the UTF-8 encoding of the characters for insertion events in the same order as they appear in the first column, and LZ4-compress.
- _Parents._ By default we assume that every event has exactly one parent, namely its predecessor in the topological sort. Any events for which this is not true are listed explicitly, for example: "the first event has zero parents; the 153rd event has two parents, namely events numbers 31 and 152;" and so on.
- _Event IDs._ Each event is uniquely identified by a pair of a replica ID and a per-replica sequence number. This column stores runs of event IDs, for example: "the first 1085 events are from replica $A$, starting with sequence number 0; the next 595 events are from replica $B$, starting with sequence number 0;" and so on.
// - _Cached transform positions (optional)._ We can optionally store the transformed positions of each event. This allows the document state to be recomputed much faster in many cases. And because of the similarity between transformed positions and original positions, this data adds a very small amount of file overhead in practice.

// TODO: the next two paragraphs could be omitted if we're short of space
We use several further tricks to reduce file size. For example, we run-length-encode deletions in reverse direction (due to holding down backspace). We express operation indexes relative to the end of the previous event, so that the number fits in fewer bytes. We deduplicate replica IDs, and so on.

Peers can optionally also store a copy of the document's content, after all changes have been merged. This allows documents to be loaded directly from disk, without any additional overhead. (The event graph is only needed when merging concurrent changes).

We send the same data format over the network when replicating the entire event graph.
When sending a subset of events over the network (e.g., a single event during real-time collaboration), references to parent events outside of that subset need to be encoded using the $(italic("replicaID"), italic("seqNo"))$ event IDs, but otherwise a similar encoding can be used.

= Evaluation <benchmarking>

// Hints for writing systems papers https://irenezhang.net/blog/2021/06/05/hints.html
// Benchmarking crimes to avoid https://gernot-heiser.org/benchmarking-crimes.html

// TODO: anonymise the references to repos for the conference submission
// Can use a service like https://anonymous.4open.science/

We created a TypeScript implementation of #algname optimised for simplicity and readability#if not anonymous {[ @reference-reg]}, and a production-ready Rust implementation optimised for performance#if not anonymous {[ @dt]}.
The TypeScript version omits several optimisations, including run-length encoding of the internal state, the B-trees, and topological sorting heuristics.
The results in this section are based on the Rust implementation.

We compare #algname with two popular CRDT libraries: Automerge v0.5.9 @automerge (Rust) and Yjs v13.6.10 @yjs (JavaScript).#footnote[We also tested Yrs @yrs, the Rust rewrite of Yjs by the original authors. At the time of writing it performs worse than Yjs, so we have omitted it from our results.]
We only test their collaborative text datatypes, and not the other features they support.
However, the performance of these libraries varies widely.
In an effort to distinguish between implementation differences and algorithmic differences, we have also implemented our own performance-optimised reference CRDT library.
This library shares most of its code with our Rust #algname implementation, enabling a more like-to-like comparison between the traditional CRDT approach and #algname.
Our reference CRDT outperforms both Yjs and Automerge.

We have also implemented a simple OT library using the TTF algorithm @Oster2006TTF.
(We do not use the server-based Jupiter algorithm @Nichols1995 or the popular OT library ShareDB @sharedb because they do not support the branching and merging patterns that occur in some of our dataset.)
// This OT library batch transforms operations in a given event graph. Intermediate transformed operations are memoized and reused during the graph traversal - which dramatically improves performance but also increases memory usage. This library has not been optimised as thoroughly as the other code.

We compare these implementations along 3 dimensions:
#footnote[Experimental setup: We ran the benchmarks on a Ryzen 7950x CPU running Linux 6.5.0-28 and 64GB of RAM.
We compiled Rust code with rustc v1.78.0 in release mode with `-C target-cpu=native`. Rust code was pinned to a single CPU core to improve run-to-run stability. // (The reason is that different cores of the same CPU are clocked differently due to thermal reasons. Using a single core improves run-to-run stability).
For JavaScript (Yjs) we used Node.js v21.7.0. // Javascript wasn't pinned to a single core. Nodejs uses additional cores to run the V8 optimizer.
All reported time measurements are the mean of at least 100 test iterations (except for the case where OT takes an hour to merge trace A2, which we ran 10 times).
The standard deviation for all benchmark results was less than 1%, hence we do not show error bars.]

/ Speed: The CPU time to load a document into memory, and to merge a set of updates from a remote replica.
/ Memory usage: The RAM used while a document is loaded and while merging remote updates.
/ Storage size: The number of bytes needed to persistently store a document or replicate it over the network.

== Editing traces

As there is no existing benchmark for collaborative text editing, we collected a set of editing traces from real documents.
#if anonymous {
  [All code and data used in our benchmarks is available for anybody to reproduce.#footnote[TODO: anonymised link to download]]
} else {
  [We have made these traces freely available on GitHub @editing-traces.]
}
For this evaluation we replay seven traces, which fall in three categories:

/ Sequential Traces: (S1, S2, S3): One author, or multiple authors taking turns (no concurrency).
/ Concurrent Traces: (C1, C2): Multiple users concurrently editing the same document with $approx$1 second latency. Many short-lived branches with frequent merges.
/ Asynchronous Traces: (A1, A2): Event graphs derived from branching/merging Git commit histories. Multiple long-running branches and infrequent merges.

We recorded the sequential and concurrent traces with keystroke granularity using an instrumented text editor.
To make the traces easier to compare, we normalised them so that each trace contains $approx$500k inserted characters (>100 printed pages).
We extended shorter traces to this length by repeating them several times.
See @traces-appendix for details.

== Time taken to load and merge changes

// TODO(seph): Long sentence. Revise.
The slowest operations in many collaborative editors are merging a large set of edits from a remote replica into the local replica state, and loading a document from disk so that it can be displayed and edited.
To simulate a worst-case merge, we start with an empty document and then merge an entire editing trace into it.
In the case of #algname this means replaying the full trace.
@chart-remote shows the time taken by each algorithm to perform this merge.
// For the CRDT implementations, all events were preprocessed into the appropriate CRDT message format. The time taken to do this is not included in our measurements.

After completing this merge, we saved the resulting local replica state to disk and measured the CPU time to load it back into memory.
In the CRDT implementations we tested, loading a document from disk is equivalent to merging the remote events, so we do not show CRDT loading times separately in @chart-remote.
OT and #algname can load documents hundreds of times faster by caching the final document state on disk, and reloading the document text directly.
These algorithms only need to reload historical events when merging concurrent changes or to reconstruct old document versions.
However, this comes at the cost of consuming additional space.
// TODO(seph): This sentence is awkward. We talk about CRDTs, then OT+egwalker, then CRDTs again? Clean me!
Existing CRDTs cannot defer this work as they require the CRDT state to be in memory to allow a user to make local edits.

// For completeness, we also measured the time taken to process local editing events. However, all of the systems we tested can process events many orders of magnitude much faster than any human's typing speed. We have not shown this data as at that speed, the differences between systems are irrelevant.

#figure(
  text(8pt, charts.speed_merge),
  caption: [
    The CPU time taken by each algorithm to merge all events in each trace (as received from a remote replica), or to reload the resulting document from disk. The CRDT implementations (Ref CRDT, Automerge and Yjs) take the same amount of time to merge changes as they do to subsequently load the document. The red line at 16 ms indicates the time budget available to an application that wants to show the results of an operation by the next frame, assuming a display with a 60 Hz refresh rate.
  ],
  kind: image,
  placement: top,
) <chart-remote>

We can see in @chart-remote that #algname and OT are very fast to merge the sequential traces (S1, S2, S3), since they simply apply the operations with no transformation.
However, OT performance degrades dramatically on the asynchronous traces (6 seconds for A1, and 1 hour for A2) due to the quadratic complexity of the algorithm, whereas #algname remains fast (160,000$times$ faster in the case of A2).

On the concurrent traces (C1, C2) and asynchronous trace A2, the merge time of #algname is similar to that of our reference CRDT, since they perform similar work.
Both are significantly faster than the state-of-the-art Yjs and Automerge CRDT libraries; this is due to implementation differences and not fundamental algorithmic reasons.

On the sequential traces #algname outperforms our reference CRDT by a factor of 7--10$times$, and on trace A1 (which contains large sequential sections) #algname is 5$times$ faster.
Comparing to Yjs or Automerge, this speedup is greater still.
This is due to #algname's ability to clear its internal state and skip all of the internal state manipulation on critical versions (@clearing).
To quantify this effect, we compare #algname's performance with a version of the algorithm that has these optimisations disabled.
@speed-ff shows the time taken to replay all our traces with this optimisation enabled and disabled.
We see that the optimisation is effective for S1, S2, S3, and A1, whereas for C1, C2, and A2 it makes little difference (A2 contains no critical versions).

#figure(
  text(8pt, charts.speed_ff),
  caption: [
    Time taken for #algname to merge all events in a trace, with and without the optimisations from @clearing.
  ],
  kind: image,
  placement: top,
) <speed-ff>

Automerge's merge times on traces C1 and C2 are outliers. This appears to be a bug, which we have reported.

When merging an event graph with very high concurrency (like A2), the performance of #algname is highly dependent on the order in which events are traversed.
A poorly chosen traversal order can make this trace as much as 8$times$ slower to merge. Our topological sort algorithm (@graph-walk) tries to avoid such pathological cases.
// (Seph) This is no longer true - I optimised it.
// However, the topological sort itself also takes time: in the C1 and C2 traces, about 40% of the runtime is the topological sort, as there are thousands of tiny branch and merge points due to the fine-grained concurrency.

== RAM usage

@chart-memusage shows the memory footprint (retained heap size) of each algorithm.
The memory used by #algname and OT is split into peak usage (during the merge process) and the "steady state" memory usage, after temporary data such as #algname's internal state is discarded and the event graph is written out to disk.
For the CRDTs the difference between peak and steady-state memory use is small.

#algname's peak memory use is similar to our reference CRDT: slightly lower on the sequential traces, and approximately double for the concurrent traces.
However, the steady-state memory use of #algname is 1--2 orders of magnitude lower than the best CRDT.
This is a significant result, since the steady state is what matters during normal operation while a document is being edited.
Note also that peak memory usage would be lower when replaying a subset of an event graph, which is likely to be the common case.

// (seph): The peak memory usage could be reduced a lot if I first divide up the graph into chunks by the critical versions. Right now, the implementation makes a "merge plan" for the whole thing (which is stored in memory) then processes the entire plan. The plan itself uses up a lot of memory. A better approach would chunk it in sections separated by critical versions. That would dramatically reduce peak memory usage!

Yjs has slightly higher memory use than our reference CRDT, and Automerge significantly higher.
Automerge's very high memory use on C1 and C2 is probably a bug.
The computer we used for benchmarking had enough RAM to prevent swapping in all cases.

OT has the same memory use as #algname in the steady state, but significantly higher peak memory use on the C1, C2, and A2 traces (6.8~GiB for A2).
The reason is that our OT implementation memoizes intermediate transformed operations to improve performance.
This memory use could be reduced at the cost of increased merge times.

#figure(
  text(7pt, charts.memusage_all),
  caption: [
    RAM used while merging an editing trace received from another replica. #algname and OT only retain the current document text in the steady state, but need additional RAM at peak while merging concurrent changes.
  ],
  kind: image,
  placement: top,
) <chart-memusage>


== Storage size

Our binary encoding of event graphs (@storage) results in smaller files than the equivalent internal CRDT state persisted by Automerge or Yjs.
To ensure a like-for-like comparison we have disabled #algname's built-in LZ4 and Automerge's built-in gzip compression. Enabling this compression further reduces the file sizes.

// TODO: I wonder if it would be worth adding zlib compression (matching automerge)? It would be a small change.

Automerge stores the full editing history of a document, and @chart-dt-vs-automerge shows the resulting file sizes relative to the raw concatenated text content of all insertions, with and without a cached copy of the final document text.
In all of our traces, #algname has a significantly smaller overhead.


// TODO: Is this worth adding?
// Note that storing the raw editing trace in this compact form removes one of the principle benefits of #algname, as the event graph must be replayed in order to determine the current document text. To improve load time, the current text content can be cached and stored alongside the event graph on disk. Alternately, the transformed operation positions can also be stored in the file. In our testing, this resulted in a tiny increase in file size while improving load performance by an order of magnitude.

In contrast, Yjs only stores the text of the resulting, merged document. This results in a smaller file size, and in the case of #algname, much faster loading times. However, the resulting systems cannot reconstruct earlier document states.
@chart-dt-vs-yjs compares Yjs to the equivalent event graph encoding in which we only store the resulting document text and operation metadata.
Our encoding is smaller than Yjs on all traces. The overhead of storing the event graph is between 20% and 3$times$ the final plain text file size.
// Using this scheme, #algname can still merge editing events and load the document text directly from disk.

#figure(
  text(8pt, charts.filesize_full),
  caption: [
    File size storing edit traces using #algname's event graph encoding (with and without final document caching) compared to Automerge. The lightly shaded region in each bar shows the concatenated length of all stored text. This acts as lower bound on the file size.
  ],
  kind: image,
  placement: top,
) <chart-dt-vs-automerge>

#figure(
  text(8pt, charts.filesize_smol),
  caption: [File size storing edit traces in which deleted text content has been omitted, as is the case with Yjs. The lightly shaded region in each bar is the size of the final document, which is a lower bound on the file size.],
  kind: image,
  placement: top,
) <chart-dt-vs-yjs>


= Related Work <related-work>

#algname is an example of a _pure operation-based CRDT_ @polog, which is a family of algorithms that capture a DAG (or partially ordered log) of operations in the form they were generated, and define the current state as a query over that log.
However, existing publications on pure operation-based CRDTs @Almeida2023 @Bauwens2023 present only datatypes such as maps, sets, and registers; #algname adds a list/text datatype to this family.

MRDTs @Soundarapandian2022 are similarly based on a DAG, and use a three-way merge function to combine two branches since their lowest common ancestor; if the LCA is not unique, a recursive merge is used.
MRDTs for various datatypes have been defined, but so far none offers text with arbitrary insertion and deletion.

Toomim's _time machines_ approach @time-machines shares a conceptual foundation with #algname: both are based on traversing an event graph, with operations being transformed from their original form into a form that can be applied in topologically sorted order.
Toomim also points out that CRDTs can implement this transformation.
#algname is a concrete, optimised implementation of the time machine approach; novel contributions of #algname include updating the prepare version by retreating and advancing, as well as the details of partial event graph replay.

#algname is also an _operational transformation_ (OT) algorithm @Ellis1989. // since it takes operations that insert or delete characters at some index, and transforms them into operations that can be applied to the local replica state to have an effect equivalent to the original operation in the state in which it was generated.
OT has a long lineage of research going back to the 1990s @Nichols1995 @Ressel1996 @Sun1998.
To our knowledge, all existing OT algorithms consist of a set of _transformation functions_ that transform one operation with regard to one other operation, and a _control algorithm_ that traverses an editing history and invokes the necessary transformations.
A problem with this architecture is that when two replicas have diverged and each performed $n$ operations, merging their states unavoidably has a cost of at least $O(n^2)$; in some OT algorithms the cost is cubic or even worse @Li2006 @Roh2011RGA @Sun2020OT.
#algname departs from the transformation function/control algorithm architecture and instead performs transformations using an internal CRDT state, which reduces the merging cost to $O(n log n)$ in most cases; the upper bound of $O(n^2 log n)$ is unlikely to occur in practical editing histories.

/*
Moreover, most practical implementations of OT require a central server to impose a total order on operations.
Although it is possible to perform OT in a peer-to-peer context without a central server @Sun2020OT, several early published peer-to-peer OT algorithms later turned out to be flawed @Imine2003 @Oster2006TTF, leaving OT with a reputation of being difficult to reason about @Levien2016.
We have not formally evaluated the ease of understanding #algname, but we believe that it is easier to establish the correctness of our approach compared to distributed OT algorithms.
*/

Other collaborative text editing algorithms @Preguica2009 @Roh2011RGA @fugue @Weiss2010 belong to the family of _conflict-free replicated data types_ (CRDTs) @Shapiro2011.
To our knowledge, all existing CRDTs for text work by assigning each character a unique ID, and translating index-based insertions and deletions into ID-based ones.
These unique IDs need to be held in memory when a document is being edited, persisted for the lifetime of the document, and sent to all replicas.
In contrast, #algname uses unique IDs only transiently during replay but does not persist or replicate them, and it can free all of its internal state whenever a critical version is reached.
#algname needs to store the event graph as long as concurrent operations may arrive, but this takes less space than CRDT state, and it only needs to be in-memory while merging concurrent operations.
Most of the time the event graph can remain on disk.

Gu et al.'s _mark & retrace_ method @Gu2005 is superficially similar to #algname, but it differs in several important details: it builds a CRDT-like structure containing the entire editing history, not only the parts being merged, and its ordering of concurrent insertions is prone to interleaving.

// TODO: also mention Pijul and Darcs?
Version control systems such as Git, as well as differential synchronization @Fraser2009, perform merges by diffing the old and new states on one branch, and applying the diff to the other branch.
Applying patches relies on heuristics, such as searching for some amount of context before and after the modified text passage, which can apply the patch in the wrong place if the same context exists in multiple locations, and which can fail if the context has concurrently been modified.
These systems therefore require manual merge conflict resolution and don't guarantee automatic convergence.


= Conclusion

#algname is a new approach to collaborative text editing.
It is orders of magnitude faster than existing OT and CRDT algorithms in the best cases, and competitive with the fastest existing implementations in the worst cases.
Compared to CRDTs, it uses less memory, files are smaller and faster to load, and edits from other users are merged much faster in documents with largely sequential editing.
Compared to OT, large merges (e.g., from users who did a significant amount of work while offline) are much faster, and peer-to-peer collaboration is robustly supported.

Since #algname stores the full keystroke-granularity editing history of a document, it allows applications to show that history to the user, and to restore arbitrary past versions of a document by replaying subsets of the graph.
The underlying event graph is a straightforward representation of the edits that have occurred, which is easy to replicate over any network, and which is not specific to the #algname algorithm.
We expect that the same data format will be able to support future collaborative editing algorithms as well, without requiring the data format to be changed.

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

= Editing Traces <traces-appendix>

@traces-table gives an overview of the editing traces used in our evaluation (@benchmarking).
All traces are freely available for benchmarking collaborative text editing algorithms
#if anonymous {
  [(link elided for anonymous review).]
} else {
  [on GitHub @editing-traces.]
}
The traces represent the editing history of the following documents:

/ Sequential Traces: These traces have no concurrency. They were recorded using an instrumented text editor that recorded keystroke-granularity editing events. Trace S1 is the LaTeX source of a journal paper #if not anonymous {[@Kleppmann2017 @automerge-perf]} written by two authors who took turns. S2 is the text of an 8,800-word, single-author blog post#if not anonymous {[ @crdts-go-brrr]}. S3 is the text of this paper that you are currently reading.
/ Concurrent Traces: Trace C1 is two users in the same document, writing a reflection on an episode of a TV series they have just watched. C2 is two users collaboratively reflecting on going to clown school together. We recorded these real-time collaborations with keystroke granularity, and we added 1~sec (C1) or 0.5~sec (C2) artificial latency between the collaborating users to increase the incidence of concurrent operations.
/ Asynchronous Traces: We reconstructed the editing trace of some files in Git repositories. The event graph mirrors the branching/merging of Git commits. Since Git does not record individual keystrokes, we generated the minimal edit operations necessary to perform each commit's diff. Trace A1 is `src/node.cc` from the Git repository for Node.js @node-src-nodecc, and A2 is `Makefile` from the Git repository for Git itself @git-makefile.

#let stats_for(name, type, num_authors: none) = {
  let data = json("results/dataset_stats.json").at(name)

  // let a = num_authors
  if num_authors == none {
    num_authors = data.num_agents
  }

  (
    name,
    type,
    str(calc.round(data.total_keystrokes / 1000)),
    str(calc.round(data.concurrency_estimate, digits: 2)),
    str(data.graph_rle_size),
    str(num_authors)
  )
}

#figure(
  text(8pt, table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (center, center, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Name*], [*Type*], [*Events (k)*], [*Avg. Conc.*], [*Runs*], [*Authors*]),
    table.hline(stroke: 0.4pt),

    ..stats_for("S1", "seq", num_authors: 2),
    ..stats_for("S2", "seq"),
    ..stats_for("S3", "seq", num_authors: 2),
    ..stats_for("C1", "conc"),
    ..stats_for("C2", "conc", num_authors: 2),
    ..stats_for("A1", "async"),
    ..stats_for("A2", "async"),
    table.hline(stroke: 0.8pt),
  )),
  placement: top,
  caption: [
    The text editing traces used in our evaluation. _Events_: total number of editing events, in thousands. Each inserted or deleted character counts as one event. _Average concurrency_: mean number of concurrent branches per event in the trace. _Runs_: number of sequential runs (linear event sequences without branching/merging). _Authors_: number of users who added at least one event.
  ]
) <traces-table>

We recorded the sequential and concurrent traces ourselves, collaborating with friends or colleagues.
#if anonymous {[Please note that as a result, the trace data contains the names of the authors of this paper, and it is not anonymised.]}
All contributors to the traces have given their consent for their recorded keystroke data to be made publicly available and to be used for benchmarking purposes.
The asynchronous traces are derived from public data on GitHub.

The recorded editing traces originally varied a great deal in size.
To allow easier comparison of measurements between traces, we have roughly standardised the sizes of all editing traces to contain approximately 500k inserted characters.
We did this by duplicating the shorter event graphs multiple times in our data files, without introducing any concurrency (that is, all events from one run of the trace happen either before or after all events from another run).
We repeat the original S1 and S2 traces 3 times, the original C1 and C2 traces 25 times, and the original A2 trace twice.
The statistics given in @traces-table are after duplication.

= Proof of Correctness <proofs>

We now demonstrate that #algname is a correct collaborative text algorithm by showing that it satisfies the _strong list specification_ proposed by Attiya et al. @Attiya2016.
Informally speaking, this specification requires that replicas converge to the same document state, that this state contains exactly those characters that were inserted but not deleted, and that inserted characters appear in the correct place relative to the characters that surrounded it at the time it was inserted.
Assuming network partitions are eventually repaired, this is a stronger specification than _strong eventual consistency_ @Shapiro2011, which is a standard correctness criterion for CRDTs @Gomes2017verifying.

With a suitable algorithm for ordering concurrent insertions at the same position, #algname is also able to achieve maximal non-interleaving @fugue.
However, since that algorithm is out of scope of this paper, we also leave the proof of non-interleaving out of scope.

Let $sans("Char")$ be the set of characters that can be inserted in a document.
Let $sans("Op") = {italic("Insert")(i, c) | i in NN and c in sans("Char")} union {italic("Delete")(i) | i in NN}$ be the set of possible operations.
Let $sans("ID")$ be the set of unique event identifiers, and let $sans("Evt") = sans("ID") times cal(P)(sans("ID")) times sans("Op")$ be the set of possible events consisting of a unique ID, a set of parent event IDs, and an operation.
When $e in G$ and $e = (i,p,o)$ we also use the notation $e.italic("id") = i$, $e.italic("parents") = p$, and $e.italic("op") = o$.

We say that an event graph $G subset.eq sans("Evt")$ is _valid_ if:
1. every event $e in G$ has an ID $e.italic("id")$ that is unique in $G$;
2. for every event $e in G$, every parent ID $p in e.italic("parents")$ is the ID of some other event in $G$;
3. the graph is acyclic, i.e. there is no subset of events ${e_1, e_2, ..., e_n} subset.eq G$ such that $e_1$ is a parent of $e_2$, $e_2$ is a parent of $e_3$, ..., and $e_n$ is a parent of $e_1$; and
4. for every event $e in G$, the index at which $e.italic("op")$ inserts or deletes is an index that exists (is not beyond the end of the document) in the document version defined by the parents $e.italic("parents")$.

Since event graphs grow monotonically and we never remove events, it is easy to ensure that the graph remains valid whenever a new event is added to it.

Given an event graph $G$ we define a replay function $sans("replay")(G)$ as introduced in @replay, based on the #algname algorithm.
It iterates over the events in $G$ in some topologically sorted order, transforming the operation in each event as described in @algorithm, and then applying the transformed operation to the document state resulting from the operations applied so far (starting with the empty document).
In a real implementation, $sans("replay")$ returns the final document state as a concatenated sequence of characters.
For the sake of this proof, we define $sans("replay")$ to instead return a sequence of $(italic("id"), c)$ pairs, where $italic("id")$ is the unique ID of the event that inserted the character $c$.
This allows us to distinguish between different occurrences of the same character.
The text of the document can be recovered by simply ignoring the $italic("id")$ of each pair and concatenating the characters.

#lemma[Let $G$ be a valid event graph with ${a, b} subset.eq sans("Version")(G)$. Let the event sequence $E = angle.l e_1, e_2, ..., e_n angle.r$ be a topological sort of $G - {a, b}$. Then replaying the events $E$ in order, followed by $a$ and then $b$, results in the same document state as replaying $E$ followed by $b$ and then $a$.] <lemma-commute>
#proof[
  By induction over $n$, the length of $E$.

  Base case ($n=0$). WLOG we consider three cases: (1)~$a.italic("op") = italic("Insert")(i, c_i)$ and $b.italic("op") = italic("Insert")(j, c_j)$; (2)~$a.italic("op") = italic("Insert")(i, c)$ and $b.italic("op") = italic("Delete")(j)$; (3)~$a.italic("op") = italic("Delete")(i)$ and $b.italic("op") = italic("Delete")(j)$.
  The case where $a$ is a deletion and $b$ is an insertion is equivalent to case (2).

  TODO

  Inductive step.
  Inductive hypothesis: replaying $E_1 = angle.l e_1, e_2, ..., e_k, a, b angle.r$ results in document state $d$, and $E_2 = angle.l e_1, e_2, ..., e_k, b, a angle.r$ results in the same document $d$.
  We must show that replaying $E'_1 = angle.l e_1, e_2, ..., e_k, e_l, a, b angle.r$ results in the same document state as replaying $E'_2 = angle.l e_1, e_2, ..., e_k, e_l, b, a angle.r$, where $e_l$ is the next event after $e_k$ in $E$.

  TODO
]

#lemma[Given a valid event graph $G$, $sans("replay")(G)$ is a deterministic function.] <lemma-deterministic>
#proof[
  The algorithms to transform an operation and to apply a transformed operation to the document state are by definition deterministic.
  This leaves as the only source of nondeterminism the choice of topologically sorted order ($G$ is valid and hence acyclic, thus at least one such order exists, but there may be several topologically sorted orders if $G$ contains concurrent events).
  We show that all sort orders result in the same final document state.

  Let $E = angle.l e_1, e_2, ..., e_n angle.r$ and $E' = angle.l e'_1, e'_2, ..., e'_n angle.r$ be two topological sort orders of $G = {e_1, e_2, ..., e_n}$.
  Then $E'$ must be a permutation of $E$.
  Both sequences are in some causal order, that is: if $e_i -> e_j$ ($e_i$ happens before $e_j$, as defined in @event-graphs), then $e_i$ must appear before $e_j$ in both $E$ and $E'$.
  If $e_i parallel e_j$ (they are concurrent), the events could appear in either order.
  Therefore, it is possible to transform $E$ into $E'$ by repeatedly swapping two concurrent events that are adjacent in the sequence.
  We show that at each such swap we maintain the invariant that the document state resulting from applying the events in the order before the swap is equal to the document state resulting from applying the events in the order after the swap.
  Therefore, the document state resulting from replaying $E$ is equal to that resulting from $E'$.

  Let $angle.l e_1, e_2, ..., e_i, e_j, ..., e_n angle.r$ be the sequence of events prior to one of these swaps, and $e_i$, $e_j$ are the events to be swapped.
  The set of events $G' = {e_1, e_2, ..., e_i, e_j}$ in the prefix of this sequence up to and including $e_j$ also forms a valid event graph (in a topological sort, an event's parents must always appear earlier in the sequence, so the removal of a suffix cannot remove a parent of an event in the prefix).
  Moreover, $e_i$ and $e_j$ must both be in the frontier set of $G'$, since they are concurrent and they cannot be the parent of any other event in $G'$.
  By @lemma-commute, replaying the events in the prefix results in the same document state as replaying the events in a variant of the prefix in which $e_i$ and $e_j$ are swapped.
  Replaying the events in the suffix is a deterministic algorithm based on this document state.
  Therefore, replaying $angle.l e_1, e_2, ..., e_i, e_j, ..., e_n angle.r$ results in the same document state as replaying $angle.l e_1, e_2, ..., e_j, e_i, ..., e_n angle.r$.
]

#theorem[The #algname algorithm complies with the strong list specification @Attiya2016.] <main-theorem>
#proof[
  Attiya et al. make a simplifying assumption that every insertion operation has a unique character.
  We use a slightly stronger version of the specification that avoids this assumption.
  We also simplify the specification by using our event graph definition instead of the original abstract execution definition (containing message broadcast/receive events and a visibility relation).
  These changes do not affect the substance of the proof; the transitive closure of our event graph is equivalent to the visibility relation.

  Our version of the strong list specification requires that for every finite event graph $G subset.eq sans("Evt")$ there exists a relation $italic("lo") subset.eq G times G$ called the _list order_, such that:
  1. For every event $e in G$, let $sans("replay")({e} union sans("Events")(e.italic("parents")))$... TODO
]

#lemma[TODO]

// "given an event to be added to an existing event graph, return the (index-based) operation that must be applied to the current document state so that the resulting document is identical to replaying the entire event graph including the new event" (end of Section 2)