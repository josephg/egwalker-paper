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

#let anonymous = false

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

#align(center, text(20pt)[
  *Eg-walker: Text editing on the Event Graph*
])

#if anonymous {
  align(center, text(12pt)[
    Anonymous Author(s) \
    Submission ID: TODO
  ])
} else {
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
Existing collaboration algorithms are either slow to merge files that have diverged substantially due to offline editing (in the case of Operational Transformation/OT), or incur overheads due to giving a unique ID to every character (in the case of CRDTs).
We introduce Eg-walker, a collaboration algorithm for text that achieves the best of both the OT and the CRDT worlds: it avoids the overheads of CRDTs while simultaneously offering fast merges.
Our implementation of Eg-walker outperforms existing CRDT and OT algorithms in most editing scenarios, while also using less memory, having smaller file sizes, and supporting peer-to-peer collaboration without a central server.
*(TODO: quantify the performance improvement?)*
By offering performance that is competitive with centralised algorithms, our result paves the way towards the widespread adoption of peer-to-peer collaboration software.


= Introduction <introduction>

Real-time collaborative editing has become an essential feature for many types of software, including document editors such as Google Docs, Microsoft Word, or Overleaf, and graphics software such as Figma.
In such software, each user's device locally maintains a copy of the shared file (e.g. in a tab of their web browser).
A user's edits to the file are immediately applied to their own local copy, without waiting for a network round-trip, in order to ensure that the user interface is responsive regardless of network latency.
Different users may therefore make edits concurrently, and the software must merge such concurrent edits in a way that preserves the users' intentions, and ensuring that all devices converge towards the same state.

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

OT is simple and fast in the case of @two-inserts, where each user performed only one operation since the last version they had in common.
In general, if user 1 performed $k$ operations and user 2 performed $m$ operations since their last common version, merging their states using OT has a cost of at least $O(k m)$, since each of the $k$ operations must be transformed with respect to each of the $m$ operations and vice versa.
Some OT algorithms have a complexity that is quadratic or even cubic in the number of operations performed by each user @Li2006 @Roh2011RGA @Sun2020OT.
This is acceptable for online collaboration where $k$ and $m$ are typically small, but if users may edit a document offline or if the software supports explicit branching and merging workflows @Upwelling, an algorithm with complexity $O(k m)$ can become impracticably slow.

_Conflict-free Replicated Data Types_ (CRDTs) have been proposed as an alternative to OT.
The first CRDT for collaborative text editing appeared in 2006 @Oster2006WOOT, and over a dozen text CRDTs have been published since @crdt-papers.
These algorithms work by giving each character a unique identifier, and using those IDs instead of integer indexes to identify the position of insertions and deletions in the document.
This avoids having to transform operations (since IDs are not affected by concurrent operations), but storing and transmitting those IDs introduces overhead.
Moreover, some CRDT algorithms need to retain IDs of deleted characters (_tombstones_), which introduces further overhead.

In this paper we propose _Event Graph Walker_ (Eg-walker), an approach to collaborative editing that combines the strengths of OT and CRDT in a single algorithm.
Like OT, Eg-walker uses integer indexes to identify insertion and deletion positions, and it avoids the overheads of CRDTs at times when there is no concurrency.
On the other hand, when two users concurrently perform $k$ and $m$ operations respectively, Eg-walker can merge them at a cost of $O((k+m) log (k+m))$, which is much faster than the cost of $O(k m)$ or worse incurred by OT algorithms.

To merge concurrent operations, Eg-walker must also transform the indexes of insertions and deletions like in @two-inserts.
Instead of transforming one operation with respect to one other operation, as in OT, Eg-walker transforms sets of concurrent operations by first building a temporary data structure that reflects all of the operations that have occurred since the last version they had in common, and then using that structure to transform each operation.
In fact, we use a CRDT to implement this data structure.
However, unlike existing algorithms, we only invoke the CRDT to perform merges, and we avoid the CRDT overhead whenever operations are not concurrent (which is the common case in most editing workflows).
Moreover, we use the CRDT only temporarily for merges; we never write CRDT data to disk and never send it over the network.

The fact that both sequential operations and large merges are fast makes Eg-walker suitable for both real-time collaboration and offline work.
Moreover, since Eg-walker assumes no central server, it can be used over a peer-to-peer network.
Although all existing CRDTs and a few OT algorithms can be used peer-to-peer, most of them have poor performance compared to the centralised OT used in production software such as Google Docs.
In contrast, Eg-walker's performance matches or surpasses that of centralised algorithms.
It therefore paves the way towards the widespread adoption of peer-to-peer collaboration software, and perhaps overcoming the dominance of centralised cloud software that exists in the market today.

In this paper we focus on collaborative editing of plain text files, although we believe that our approach could be generalised to other file types such as rich text, spreadsheets, graphics, presentations, CAD drawings, etc.
This paper makes the following contributions:

- TODO
- In @benchmarking we evaluate the performance of eg-walker, comparing it to equivalent CRDT based approaches on file size, CPU time and memory usage in real world editing environments. Eg-walker is faster and smaller than equivalent CRDT based approaches in our real world data sets. However, it scales worse than CRDTs in extremely concurrent environments (eg very complex git editing histories).

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

We represent the editing history of a document as an _event graph_, which is a directed acyclic graph (DAG) in which every node is an _event_ consisting of an operation (insert or delete a character), a unique ID, and a set of IDs of its _parent nodes_.
When the parents of event $b$ contain the ID of event $a$, we say $a$ is a _parent_ of $b$, $b$ is a _child_ of $a$, and the graph contains an edge from $a$ to $b$.
We construct events such that the graph is transitively reduced (i.e., it contains no redundant edges).
When there is a directed path from $a$ to $b$ we say that $a$ _happened before_ $b$, and write $a -> b$ as per Lamport @Lamport1978.
The $->$ relation is a strict partial order.
We say that events $a$ and $b$ are _concurrent_, written $a parallel b$, if both events are in the graph, $a eq.not b$, but neither happened before the other: $a arrow.r.not b and b arrow.r.not a$.

The _frontier_ is the set of events with no children.
Whenever a user performs an operation, a new event containing that operation is added to the graph, and the previous frontier in the replica's local copy of the graph becomes the new event's parents.
The new event and its parent edges are then replicated over the network, and each replica adds them to its copy of the graph.
If any parent events are missing, the replica waits for them to arrive before adding them to the graph; the result is a simple causal broadcast protocol @Birman1991 @Cachin2011.
Two replicas can merge their event graphs by simply taking the union of their sets of events.
An event in the graph is immutable; it always represents the operation as it was originally generated, not some transformed operation.

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
It can nevertheless be stored in a very compact form by exploiting the typical editing patterns of humans writing text: characters tend to be inserted or deleted in consecutive runs, and many portions of a typical event graph are linear, with each event having one parent and one child.
We describe the storage format in more detail in @storage.

== Document versions <versions>

Let $G$ be an event graph, represented as a set of events.
Due to convergence, any two replicas that have the same set of events must be in the same state.
Therefore, the document state (sequence of characters) resulting from $G$ must be $sans("replay")(G)$, where $sans("replay")$ is some pure (deterministic and non-mutating) function.
In principle, any pure function of the set of events results in convergence, although a $sans("replay")$ function that is useful for text editing must satisfy additional criteria (see @characteristics).

In order to correctly interpret an operation such as $italic("Delete")(i)$, we need to determine which character was at index $i$ at the time when the operation was generated.
Let $e_i$ be an event; the document state when $e_i$ was generated must be $sans("replay")(G_i)$, where $G_i$ is the set of events that were known to the generating replica at the time when $e_i$ was generated (not including $e_i$ itself).
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
Say we have an existing event graph $G$ and document state $italic("doc") = sans("replay")(G)$, and an event $e$ from a remote replica is added to the graph.
We could rerun the function to obtain $italic("doc")' = sans("replay")(G union {e})$, but it would be inefficient to process the entire graph again.
Instead, we need to efficiently compute the operation to apply to $italic("doc")$ in order to obtain $italic("doc")'$.
For text documents, this incremental update is also described as an insertion or deletion at a particular index; however, the index may differ from that in the original event due to the effects of concurrent operations, and a deletion may turn into a no-op if the same character has also been deleted by a concurrent operation.

Both OT and CRDT algorithms focus on this incremental update.
If none of the events in $G$ are concurrent with $e$, OT is straightforward: the incremental update is identical to the operation in $e$, as no transformation takes place.
If there is concurrency, OT must transform each new event with regard to each existing event that is concurrent to it.

In CRDTs, each event is first translated into operations that use unique IDs instead of indexes, and then these operations are applied to a data structure that reflects all of the operations seen so far (both concurrent operations and those that happened before).
In order to update the text editor, these updates to the CRDT's internal structure need to be translated back into index-based insertions and deletions.
Many CRDT papers elide this translation from unique IDs back to indexes, but it is important for practical applications:

- Text editors use specialised data structures such as piece trees @vscode-buffer to efficiently edit large documents, and integrating with these structures requires index-based operations. Incrementally updating these structures also enables syntax highlighting without having to repeatedly parse the whole file on every keystroke.
- The user's cursor position in a document can be represented as an index; if another user changes text earlier in the document, index-based operations make it easy to update the cursor so that it remains in the correct position relative to the surrounding text.

Thus, regardless of whether the OT or the CRDT approach is used, a collaborative editing algorithm can be boiled down to an incremental update to an event graph: given an event to be added to an existing event graph, return the (index-based) operation that must be applied to the current document state so that the resulting document is identical to replaying the entire event graph including the new event.

= The Event Graph Walker algorithm

Eg-walker is a collaborative text editing algorithm based on the idea of replaying an event graph.
The algorithm builds on a replication layer that ensures that all non-crashed replicas eventually receive every event that any replica adds to the graph.
The state of each replica consists of three parts:

1. *Event graph:* Each replica stores a copy of the event graph on disk, in a format described in @storage.
2. *Document state:* The current sequence of characters in the document with no further metadata. On disk this is simply a plain text file; in memory it may be represented as a rope @Boehm1995, piece table @vscode-buffer, or similar structure to support efficient insertions and deletions.
3. *Internal state:* A temporary CRDT structure that eg-walker uses to merge concurrent edits. It is not persisted or replicated, and it is discarded when the algorithm finishes running.

Eg-walker can reconstruct the document state by replaying the entire event graph.
It first performs a topological sort, as illustrated in @topological-sort, and then transforms each event so that the transformed insertions and deletions can be applied in topologically sorted order, starting with an empty document, to obtain the document state.
In Git parlance, this process "rebases" a DAG of operations into a linear operation history with the same effect.
The input of the algorithm is the event graph, and the output is this topologically sorted sequence of transformed operations.
In graphs with concurrent operations there are multiple possible sort orders, and eg-walker guarantees that the final document state is the same, regardless which of these orders is chosen.

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

For example, the graph in @graph-example has two possible sort orders; eg-walker either first inserts "l" at index 3 and then the exclamation mark at index 5 (like User 1 in @two-inserts), or first inserts "!" at index 4 followed by "l" at index 3 (like User 2 in @two-inserts); the final document state is "Hello!" either way.
However, the choice of sort order affects the performance of the algorithm, as discussed in @complexity.

Event graph replay easily extends to incremental updates for real-time collaboration: when a new event is added to the graph, it becomes the next element of the topologically sorted sequence.
We can transform each new event in the same way as during replay, and apply the transformed operation to the current document state.

== Characteristics of Eg-walker <characteristics>

Eg-walker ensures that the resulting document state is consistent with Attiya et al.'s _strong list specification_ @Attiya2016 (in essence, replicas converge to the same state and apply operations in the right place), and it is _maximally non-interleaving_ @fugue (i.e., concurrent sequences of insertions at the same position are placed one after another, and not interleaved).

One way of achieving this goal would be to track the state of the document on each branch of the event graph, to translate each event into a corresponding CRDT operation (based on the document state in which that event was generated), and when branches in the event graph merge, to apply the CRDT operations from one branch to the other branch's state.
Essentially, this approach simulates a network of communicating CRDT replicas and their states.
However, doing this naively leads to poor performance, because the CRDT overhead is incurred on every operation.

Eg-walker is able to achieve much better performance by skipping the CRDT entirely in portions of the event graph that have no concurrency (which, in many editing histories, is the vast majority of the graph), and using the CRDT only for concurrent events.
When processing an event that has no concurrent events, eg-walker is able to discard all of the internal state accumulated so far, keeping the data structure small.
A key contribution of eg-walker is that it can compute the correct transformed operations even though the internal state may reflect only a small part of the event graph.

Moreover, eg-walker does not need the event graph and the internal state when generating new events, or when adding an event to the graph that happened after all existing events.
Most of the time, we only need the current document state; the event graph can remain on disk without using any space in memory or any CPU time.
The event graph is only required when handling concurrency, and even then we only have to replay the portion of the graph since the last ancestor that the concurrent operations had in common.

Eg-walker's approach contrasts with existing CRDTs, which require every replica to persist the internal state (including the unique ID for each character) and send it over the network, and which require that state to be loaded into memory in order to both generate and receive operations, even when there is no concurrency.
This can use significant amounts of memory and can make documents slow to load.

OT algorithms avoid this internal state; similarly to eg-walker, they only need to persist the latest document state and the history of operations that are concurrent to operations that may arrive in the future.
In both eg-walker and OT, the editing history/event graph can be discarded if we know that no event we may receive in the future will be concurrent with any existing event.
However, OT algorithms have asymptotically worse performance than eg-walker in transforming concurrent operations (see @complexity).
Some OT algorithms are only able to handle restricted forms of event graphs, whereas eg-walker handles arbitrary DAGs.

== Walking the event graph

For the sake of clarity we first explain a simplified version of eg-walker that replays the entire event graph without discarding its internal state along the way, and that incurs CRDT overhead even for non-concurrent operations.
In @partial-replay we show how the algorithm can be optimised to replay only a part of the event graph.

First, we topologically sort the event graph in a way that keeps events on the same branch consecutive as much as possible: for example, in @topological-sort we first visit $e_"A1" ... e_"A4"$, then $e_"B1" ... e_"B4"$; we avoid alternating between branches, such as $e_"A1", e_"B1", e_"A2", e_"B2" ...$, even though that would also be a valid topological sort.
For this we use a standard textbook algorithm @CLRS2009: perform a depth-first traversal starting from the oldest event, and build up the topologically sorted list in reverse order while returning from the traversal.
When a node has multiple children, we choose their order based on a heuristic so that branches with fewer events tend to appear before branches with more events in the sorted order; this can improve performance but is not essential.
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
2. Before we can apply $e_5$ we must rewind the prepare version to be $e_2$, which is the parent of $e_5$. We can do this by calling $sans("retreat")(e_4)$ and $sans("retreat")(e_3)$.
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
A record is inserted into this sequence by $sans("apply")(e_i)$ for an insertion event $e_i$; subsequent deletion events and $sans("retreat")$/$sans("advance")$ calls may modify properties of the record, but records in the sequence are not removed or reordered once they have been inserted.

When the event graph contains concurrent insertion operations, we use an existing CRDT algorithm to ensure that all replicas place the records in this sequence in the same order, regardless of the order in which they traverse the event graph.
Any list CRDT could be used for this purpose; the main differences between algorithms are their performance and their interleaving characteristics @fugue.
Our implementation of eg-walker uses a variant of the Yjs algorithm @yjs @Nicolaescu2016YATA that we conjecture to be maximally non-interleaving; we leave a detailed analysis of this algorithm to future work, since it is not core to this paper.

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
  caption: [The internal eg-walker state after replaying all of the events in @graph-hi-hey.]
) <crdt-state-2>

@crdt-state-2 shows the state after replaying all of the events in @graph-hi-hey: "i" is also deleted, the characters "e" and "y" are inserted immediately after the "h", $e_3$ and $e_4$ are advanced again, and finally the exclamation mark is inserted after the "y".
The figures include the character for the sake of readability, but the algorithm actually does not need to store characters in its internal state.

== Mapping indexes to character IDs

In the event graph, insertion and deletion operations specify the index at which they apply; in order to update eg-walker's internal state, we need to map these to the correct record in the sequence.
Moreover, to produce the transformed operations, we need to map the positions of these internal records back to indexes again.

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

Besides the sequence of records, the internal state also includes a mapping from event ID to the record in the sequence affected by that event.
On every $sans("apply")(e)$ we use the above process to identify the target record in the sequence, and then we store the mapping from $e.italic("id")$ to the target record ID.
When we subsequently perform a $sans("retreat")(e)$ or $sans("advance")(e)$, that event $e$ must have already been applied, and hence $e.italic("id")$ must appear in this mapping.
We can therefore ignore the operation index when retreating and advancing, and instead use the event ID to look up the record to be updated.
To this end we maintain a second B-tree that is keyed by record ID, and which points at the leaf nodes of the first B-tree.
This tree allows us to advance or retreat in logarithmic time.
When nodes in the first B-tree are split, we update the pointers in the second B-tree accordingly.

== Clearing the internal state <clearing>

As described so far, the algorithm retains every insertion since document creation forever in its internal state, consuming a lot of memory, and requiring the entire event graph to be replayed in order to restore the internal state.
We now introduce a further optimisation that allows eg-walker to completely discard its internal state from time to time, and replay only a subset of the event graph.

We define a version $V subset.eq G$ to be a _critical version_ in an event graph $G$ iff it partitions the graph into two subsets of events $G_1 = sans("Events")(V)$ and $G_2 = G - G_1$ such that all events in $G_1$ happened before all events in $G_2$:
$ forall e_1 in G_1: forall e_2 in G_2: e_1 -> e_2. $

Equivalently, $V$ is a critical version iff every event in the graph is either included in $V$ or happened after _all_ of the events in $V$:
$ forall e_1 in G: e_1 in sans("Events")(V) or (forall e_2 in V: e_2 -> e_1). $
If a version is critical, that does not guarantee that it will remain critical forever; it is possible for a critical version to become non-critical because a concurrent event is added to the graph.
This concept enables several key optimisations:

- If the version of the event graph processed so far is critical, we can discard all of the internal state (including both B-trees and all $s_p$ and $s_e$ values), and replace it with a placeholder as explained in @partial-replay.
- If the parents of the next event are equal to the version of the event graph processed so far, we just output the unmodified operation from the event as the transformed operation.
- If both an event's version and its parent version are critical versions, there is no need to traverse the B-trees and update the CRDT state, since we would immediately discard that state anyway; we can just skip this work.

These optimisations make it very fast to process documents that are mostly edited sequentially (e.g., because the authors took turns and did not write concurrently, or because there is only a single author), since most of the event graph of such a document is a linear chain of critical versions.
Moreover, the internal state can be discarded once replay is complete, although it is also possible to retain the internal state for transforming future events.

If a replica receives events that are concurrent with existing events in its graph, but the replica has already discarded its internal state resulting from those events, it needs to rebuild some of that state.
It can do this by identifying the most recent critical version that happened before the new event, replaying the existing events that happened after that critical version (in topologically sorted order), and finally applying the new events.
Events from before that critical version do not need to be replayed.
Since most editing histories have critical versions from time to time, this means that usually only a small subset of the event graph needs to be replayed.
In the worst case, this algorithm replays the entire event graph.

== Partial event graph replay <partial-replay>

Assume that we want to add event $e_"new"$ to the event graph $G$, that $V_"curr" = sans("Version")(G)$ is the current document version reflecting all events except $e_"new"$, and that $V_"crit" eq.not V_"curr"$ is the latest critical version in $G union {e_"new"}$ that happened before both $e_"new"$ and $V_"curr"$.
Further assume that we have discarded the internal state, so the only information we have is the latest document state at $V_"curr"$ and the event graph; in particular, without replaying the entire event graph we do not know the document state at $V_"crit"$.

However, a key insight in the design of eg-walker is that the exact internal state at $V_"crit"$ is not needed; all we need is enough state to transform $e_"new"$ and rebase it onto the document at $V_"curr"$.
This internal state can be obtained by replaying the events since $V_"crit"$, that is, $G - sans("Events")(V_"crit")$, in topologically sorted order.
For example, using the graph in @topological-sort, say the current state is $G = {e_"A1" ... e_"A5", e_"B1" ... e_"B4"}$, so $V_"curr" = {e_"A5", e_"B4"}$, and the new event $e_"new" = e_"C1"$.
Then $V_"crit" = {e_"A1"}$ is the most recent critical version.

The algorithm then works as follows:

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
The algorithm never needs to retreat or advance an event that happened before $V_"crit"$, therefore every retreated or advanced event ID must exist in the mapping from event ID to internal state record.

If there are concurrent insertions at the same position, we invoke the CRDT algorithm to place them in a consistent order as discussed in @prepare-effect-versions.
Since all concurrent events must be after $V_"crit"$, they are included in the replay.
When we are seeking for the insertion position, we never need to seek past a placeholder, since the placeholder represents characters that were inserted before $V_"crit"$.

== Algorithm complexity <complexity>

Say we have two users who have been working offline, generating $k$ and $m$ events respectively.
When they come online and merge their event graphs, the latest critical version is immediately prior to the branching point.
If the branch of $k$ events comes first in the topological sort, the replay algorithm first applies $k$ events, then retreats $k$ events, applies $m$ events, and finally advances $k$ events again.
Asymptotically, $O(k+m)$ calls to apply/retreat/advance are required regardless of the order of traversal, although in practice the algorithm is faster if $k<m$ since we don't need to retreat/advance on the branch that is visited last.

Each apply/retreat/advance requires one or two traversals of the order statistic tree, and at most one traversal of the ID-keyed B-tree.
The upper bound on the number of entries in each tree (including placeholders) is $2(k+m)+1$, since each event generates at most one new record and one placeholder split.
Since the trees are balanced, the cost of each traversal is $O(log(k+m))$.
Overall, the cost of merging branches with $k$ and $m$ events is therefore $O((k+m) log(k+m))$.

To determine the worst-case complexity of replaying an event graph with $n$ events, note that each event is applied exactly once, and before each event we can at most retreat or advance each prior event once.
The overall worst-case complexity of the algorithm is therefore $O(n^2 log n)$; however, this case is unlikely to occur in realistic collaborative text editing scenarios.

== Storing the event graph <storage>

The event graph can be stored on disk in a very compact way by using a few compression tricks that take advantage of the ways that people typically write text documents: namely, they tend to insert or delete consecutive sequences of characters, and less frequently hit backspace or move the cursor to a new location.
Eg-walker's event graph storage format is inspired by the Automerge CRDT library @automerge-storage @automerge-columnar, which in turn uses ideas from column-oriented databases @Abadi2013 @Stonebraker2005.

We topologically sort the events in the graph; different replicas may sort the set differently, but locally to one replica we can identify an event by its index in this sorted order.
Then we store different properties of events in separate byte sequences called _columns_, which are then combined into one file with a simple header.
The columns are:

- _Event type, start position, and run length._ For example, "the first 23 events are insertions at consecutive indexes starting from index 0, the next 10 events are deletions at consecutive indexes starting from index 7," and so on. We encode this using a variable-length binary encoding of integers, which represents small numbers in one byte, larger numbers in two bytes, etc.
- _Inserted content._ An insertion event contains exactly one character (a Unicode scalar value), and a deletion does not. We can simply concatenate the UTF-8 encoding of the characters for insertion events in the same order as they appear in the first column.
- _Parents._ By default we assume that every event has exactly one parent, namely its predecessor in the topological sort. Any events for which this is not true are listed explicitly, for example: "the first event has zero parents; the 153rd event has two parents, namely events numbers 31 and 152;" and so on.
- _Event IDs._ Each event is uniquely identified by a pair of a replica ID and a per-replica sequence number. This column stores runs of event IDs, for example: "the first 1085 events are from replica $A$, starting with sequence number 0; the next 595 events are from replica $B$, starting with sequence number 0;" and so on.

We send the same data format over the network when replicating the entire event graph.
When sending a subset of events over the network (e.g., a single event during real-time collaboration), references to parent events outside of that subset need to be encoded using the $(italic("replicaID"), italic("seqNo"))$ event IDs, but otherwise a similar encoding can be used.

// Hints for writing systems papers https://irenezhang.net/blog/2021/06/05/hints.html

= Related Work <related-work>

Eg-walker is an example of a _pure operation-based CRDT_ @polog, which is a family of algorithms that capture a DAG (or partially ordered log) of operations in the form they were generated, and define the current state as a query over that log.
However, existing publications on pure operation-based CRDTs @Almeida2023 @Bauwens2023 consider only datatypes such as maps, sets, and registers; eg-walker adds a list/text datatype to this family.

MRDTs @Soundarapandian2022 are similarly based on a DAG, and use a three-way merge function to combine two branches since their lowest common ancestor; if the LCA is not unique, a recursive merge is used.
MRDTs for various datatypes have been defined, but so far none offers text with arbitrary insertion and deletion.

Toomim's _time machines_ approach @time-machines shares a conceptual foundation with eg-walker: both are based on traversing an event graph, with operations being transformed from the form in which they were originally generated into a form that can be applied in topologically sorted order to obtain the current document state.
Toomim also points out that CRDTs can be used to perform this transformation.
Eg-walker is a concrete, optimised implementation of the time machine approach; novel contributions of eg-walker include updating the prepare version by retreating and advancing, as well as the details of partial event graph replay.

Eg-walker can also be regarded as an _operational transformation_ (OT) algorithm @Ellis1989, since it takes operations that insert or delete characters at some index, and transforms them into operations that can be applied to the local replica state to have an effect equivalent to the original operation in the state in which it was generated.
OT has a long lineage of research, tracing back to several seminal papers in the 1990s @Nichols1995 @Ressel1996 @Sun1998.
To our knowledge, all existing OT algorithms follow a pattern of two sub-algorithms: a set of _transformation functions_ that transform one operation with regard to one other, concurrent operation, and a _control algorithm_ that traverses an editing history and invokes the necessary transformation functions.
A problem with this architecture is that when two replicas have diverged and each performed $n$ operations, merging their states unavoidably has a cost of at least $O(n^2)$, as each operation from one branch needs to be transformed with respect to all of the operations on the other branch; in some OT algorithms the cost is cubic or even worse @Li2006 @Roh2011RGA @Sun2020OT.
Eg-walker departs from the transformation function/control algorithm architecture and instead performs transformations using an internal CRDT state, which reduces the merging cost to $O(n log n)$ in most cases; the theoretical upper bound of $O(n^2 log n)$ is unlikely to occur in practical editing histories.

Moreover, most practical implementations of OT require a central server to impose a total order on operations.
Although it is possible to perform OT in a peer-to-peer context without a central server @Sun2020OT, several early published peer-to-peer OT algorithms later turned out to be flawed @Imine2003 @Oster2006TTF, leaving OT with a reputation of being difficult to reason about @Levien2016.
We have not formally evaluated the ease of understanding eg-walker, but we believe that it is easier to establish the correctness of our approach compared to distributed OT algorithms.

Other prominent collaborative text editing algorithms belong to the _conflict-free replicated data types_ (CRDTs) family @Shapiro2011, with early examples including RGA @Roh2011RGA, Treedoc @Preguica2009, and Logoot @Weiss2010, and Fugue @fugue being more recent.
To our knowledge, all existing CRDTs for text work by assigning every character a unique ID, and translating index-based insertions and deletions into ID-based addressing.
These unique IDs need to be persisted for the lifetime of the document and sent to all replicas, increasing I/O costs, and they need to be held in memory when a document is being edited, causing memory overhead.
In contrast, eg-walker uses unique IDs only transiently during replay but does not persist or replicate them, and it can free all of its internal state whenever a critical version is reached.
Eg-walker does need to store the event graph as long as concurrent operations may arrive, but this takes less space than CRDT metadata, and it only needs to be memory-resident to handle concurrent operations; most of the time the event graph can remain on disk.

Gu et al.'s _mark & retrace_ method @Gu2005 is superficially similar to eg-walker, but it differs in several important details: it builds a CRDT-like structure containing the entire editing history, not only the parts being merged, and its ordering of concurrent insertions is prone to interleaving.

Version control systems such as Git, as well as differential synchronization @Fraser2009, perform merges by diffing the old and new states on one branch, and applying the diff to the other branch.
Applying patches relies on heuristics, such as searching for some amount of context before and after the modified text passage, which can apply the patch in the wrong place if the same context exists in multiple locations, and which can fail if the context has concurrently been modified.
These approaches therefore generally require manual merge conflict resolution and don't ensure automatic replica convergence.


// A working typescript implementation of eg-walker is provided in our _reference-reg_ repository @reference-reg. This library is fully featured, but missing many optimisations in order to keep the code simple and easy to understand. We also provide a much more fully featured implementation of eg-walker in our _diamond types_ repository @dt. This is the implementation benchmarked in @benchmarking.


/*
#import "@preview/algorithmic:0.1.0"
#import algorithmic: algorithm

#algorithm({
  import algorithmic: *
  Function("ResetState", args: ("state",), {
    Assign[state][dummy data]
  })

  Function("TransformPartial", args: ($G$, $V_0$, $V_m$), {
    Assign[$s$][(dummy data)]
    Assign[$C$][$"greatestCommonVersion"(G)$]

    For(cond: [Event $(i, e_i, P_i) in "inOrderTraversal"(G, "from:" C, "to:" V_0)$], {
      // Cmt[As above]
      Fn[setPrepareVersion][$s$, $P_i$]
      Assign([$m$], FnI[prepare][$s$, $i$, $e_i$])
      Fn[effect][$s$, $m$]
    })
    For(cond: [Event $(i, e_i, P_i) in "inOrderTraversal"(G, "from:" V_0, "to:" V_0 union V_m)$], {
      If(cond: [$"isCriticalVersion"(P_i)$], {
        Assign[$s$][(dummy data)]
        If(cond: [$"isCriticalVersion"({i})$], {
          State[#smallcaps("yield") $e_i$]
          State(smallcaps("Continue"))
        })
      })

      Fn[setPrepareVersion][$s$, $P_i$]
      Assign([$m$], FnI[prepare][$s$, $i$, $e_i$])
      State[#smallcaps("yield") #FnI[effect][$s$, $m$]]
    })
  })
})
*/

= Evaluation <benchmarking>

In @ff-memory we see the effect this has on memory size while processing one of our real-world editing traces. The editing trace contains many critical events as the document goes in and out of sync. With fast forward optimisations enabled, the eg-walker state size stays extremely small.

#figure(
  charts.ff_chart,
  caption: [
    A comparison of the eg-walker state size while processing the _"friendsforever"_ data set, with and without fast forward optimisations enabled. //When the state is never cleared, the state grows linearly throughout the test. When the state is cleared at critical versions, it stays very small throughout this test.

    // Smaller is better.
  ],
  kind: image,
) <ff-memory>

@speed-ff shows the performance difference this optimisation makes in our various test cases. The _git-makefile_ editing trace does not contain any critical events - so performance is unchanged. In comparison, the fully sequential editing traces are processed approximately 15x faster as a result.

#figure(
  charts.speed_ff,
  caption: [
    Performance of dt-egwalker algorithm with and without
    // Smaller is better.
  ],
  kind: image,
) <speed-ff>


// // TODO: Would it be worth making a line graph out of this?
// #figure(
//   table(
//     columns: (auto, auto, auto, auto),
//     [*Dataset*], [*Before (ms)*], [*After (ms)*], [*Speedup*],
//     [automerge-perf], [3.94], [0.26], [*15x*],
//     [seph-blog1], [7.17], [0.413], [*16.6x*],
//     [friendsforever], [3.50], [2.82], [*XXX*],
//     [ETC FILL ME OUT!]
//   ),
//   // canvas(length: 1cm, {

//   // }),
//   caption: [
//     Performance comparison of _transformPartial_ with and without clearing and fast forward optimisations. All other optimisations listed in this paper are enabled. The largest gains are in the purely linear tests (automerge-perf and seph-blog1) as, for a purely linear event graph, no state needs to be constructed at all.
//   ]
// )


We were concerned that eg-walker would be too slow for practical use. To this end, we wrote a highly optimised implementation of eg-walker in rust in the Diamond Types collaborative editing library @dt. This implementation (hereafter _dt-egwalker_) performs quite well. Compared to equivalent, contemporary CRDT implementations, our eg-walker implementation is quite fast.

Eg-walker is particularly fast for linear or mostly-linear data sets where CRDT data structure does not need to be generated at all. But we suspect the algorithm scales worse than CRDTs when datasets have extremely high concurrency (eg 20+ concurrent replicas all making changes while offline). Luckily, editing scenarios like that seem extremely rare in practice.

Contemporary CRDT libraries vary wildly in performance. As @chart-one-local shows, we see a 500x difference in performance between the best performing and worst performing library we tested. In order to fairly evaluate dt-egwalker, we ended up writing our own optimised CRDT implementation in the _dt-crdt_ library@dt-crdt. This library shares its language, code style, data structures and optimisations with _dt-egwalker_ in order to achieve (as much as possible) a like-for-like comparison with diamond types. The optimisations are documented here @crdts-go-brrr.

#figure(
  text(8pt, charts.one_local),
  caption: [
    Speed locally applying the 'seph-blog1' trace to a CRDT object using various contemporary CRDTs libraries. Yjs@yjs is 500x slower than Cola@cola in this test. (2056ms vs 4ms). Cola is faster than dt-crdt due to its GTree@cola-gtree implementation using local cursor caching. When this is disabled (_cola-nocursor_), performance is remarkably similar to dt-crdt. Yjs performs much better when processing remote events.
    // Comparative speed of DT and DT-crdt algorithms processing remote data, measured in millions of run-length encoded events processed per second.
  ],
  kind: image,
) <chart-one-local>

We evaluate our system in 2 categories:

/ Speed: We measure the time taken to convert all events or CRDT messages in a document's history into the resulting document state. Messages are sent in chronological order and fully run-length encoded where possible - as they would be when reading items from disk or (in bulk) over the network.
/ Disk space: How large are editing traces or CRDT documents on disk?
// / Memory footprint: How much resident RAM does our system use while editing a document?

Event graphs also have a different resident memory profile, but we do not evaluate memory usage in this paper.

// Eg-walker is at a natural disadvantage

We do not present local speed measurements - ie, ingesting events from a local editor and (in the CRDT case) converting those events into CRDT messages. Eg-walker is much faster in this case, as no conversion needs to take place. But all of the systems we measure here are fast enough that this is not a bottleneck.

== Editing traces

Humans don't edit documents randomly. We tend to type in runs, use the backspace and delete characters interchangeably (and idiosyncratically). And we select, move, copy and paste text. Good collaborative text libraries take advantage of the features of human generated text to optimize processing - using internal run-length encoding for inserts, deletes and backspace operations, and various other tricks. To properly benchmark our libraries, its important to use input data sets that capture these real editing features.

Accurately capturing these features in a random data generator is difficult. Instead, we benchmark our system using a set of real, recorded editing traces from actual editing sessions. The traces are licensed for public use, and published on GitHub @editing-traces.

We use 2 editing traces from each of the following 3 categories, representing different classes of text editing scenarios:

/ Sequential Traces: A single user editing a document. Changes are performed in a purely linear sequence through time. We use the _automerge-perf_ trace [REF] and _seph-blog1_ trace (a recording of [CRDTS GO BRRR] from @editing-traces).
/ Concurrent Traces: Multiple users concurrently editing the same document in realtime. We use the _friendsforever_ and _clownschool_ traces from @editing-traces.
/ Asynchronous Traces: Multiple users concurrently editing a document _asynchronously_. Unfortunately, we don't have any character-by-character editing traces made this way yet, so we've written a script to reconstruct traces from individual files in git repositories. We've extracted a trace for `Makefile` from the git repository for git itself, and `src/node.cc` from the git repository for nodejs [REF]. These are some of the most edited files from their respective git repositories. Both of these files contain some extremely complex event graphs, with large merges of 6 more items.


#let stats_for(name, type) = {
  let data = json("results/stats_" + name + ".json")
  (
    name,
    type,
    str(calc.round(data.total_keystrokes / 1000, digits: 1)),
    str(calc.round(data.concurrency_estimate, digits: 2)),
    str(data.graph_rle_size),
    str(data.num_agents)
  )
}

// TODO: This is a bit ugly in column format.
#text(6pt, [
#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (center, center, right, right, right, right),
    [*Dataset*], [*Type*], [*\# Events (k)*], [*Concurrency*], [*EG RLE count*], [*\# Agents*],
    // [automerge-perf], [sequential], [259 778], [0], [1], [1],
    // [seph-blog1], [sequential], [368 209], [0], [1], [1],
    // [friendsforever], [concurrent], [26 078], [0.45], [*3685*], [2],
    // [clownschool], [concurrent], [24 326], [0.44], [*5346*], [2],
    // [node-node_cc], [async], [947 337], [0.10], [101], [194],
    // [git-Makefile], [async], [348 819], [*6.11*], [1215], [299],
    ..stats_for("automerge-paper", "sequential"),
    ..stats_for("seph-blog1", "sequential"),
    ..stats_for("egwalker", "sequential"),
    ..stats_for("friendsforever", "concurrent"),
    ..stats_for("clownschool", "concurrent"),
    ..stats_for("node_nodecc", "async"),
    ..stats_for("git-makefile", "async"),
  ),
  caption: [
    Various size measurements for the evaluation datasets. \# Events is the total number of inserted + deleted characters in the trace. Concurrency is an estimate of concurrency - during a BFS traversal of the graph, this shows the mean number of edits concurrent with each inserted or deleted character in the trace. EG RLE count is the number of nodes in the event graph when "runs" of trivial nodes (with 1 parent and 1 child) are joined together. \# Agents is the number of "user agents" which contributed to a trace. For traces from git, this is the number of unique authors which have touched the file.
  ]
)])


== Speed

There are 2 editing scenarios to consider: Local events and remote events.

Processing *local events* is rarely a bottleneck when using well written, modern collaborative editing systems. Our _dt-crdt_ implementation of Fugue can process between 5 and 10 million editing events per second - which comfortably outstrips the typing speed of most users.

More notably, while processing local editing events in a CRDT, the CRDT's prepare function needs to query the CRDT state. As a result, collaborating peers need to load the entire CRDT state to be able to generate and broadcast any locally generated events. Eg-walker has no such requirement. Events are simply appended to the local event graph and broadcast to other peers without any change. Our eg-walker implementation can ingest about 60 million changes per second in our tests - and doesn't need any data to be loaded in memory at all.

The performance while merging *remote events* is much more important. When a peer joins a network of replicas, we assume the peer is sent the entire event graph and needs to replay the event graph to calculate the resulting document state. How long does this take?

- CRDTs iteratively call their _effect_ function, adding each CRDT message to the local state object in causal order.
- Eg-walker runs the replay function listed above in [TODO EG walker algorithm REFERENCE]. // @eg-walker-algorithm

This is perhaps an unrealistically bad scenario for eg-walker. Performance would be much better if replicas simply send the text of the current document state to new peers. Historical events can be fetched lazily - they are only needed when computing old versions of the document or merging events which are concurrent with the document's current state.

Nevertheless, as we can see in @chart-remote, eg-walker is extremely fast. In absolute terms, our slowest test case (_git-makefile_) took just 15ms to process. Eg-walker is capable of processing over 1M events per second in all the test cases we have.

#figure(
  text(8pt, charts.speed_remote),
  caption: [
    Comparative speed of DT and DT-crdt algorithms processing remote data, measured in millions of run-length encoded events processed per second.
  ],
  kind: image,
) <chart-remote>

Eg-walker performance is much more varied than that of a CRDT. The reason is that the performance of a CRDT's _effect_ function is largely insensitive to the data. Eg-walker, on the other hand, is much faster than CRDTs when the event graph is largely sequential (or mostly sequential, as is the case in `node_nodecc`). This is due to the optimisations described in TODO. When part of an editing trace is sequential, the transform function resembles the identity function.

We have found that when processing datasets with very high concurrency (like _git-makefile_), the performance of eg-walker is highly dependant on the order in which events are traversed. A poorly chosen traversal order can make this test as much as 8x slower. To avoid this, we preprocess the event graph to find an ideal traversal order. However, this preprocessing itself can slow things down. In the _friendsforever_ and _clownschool_ tests, the causal graph is very "busy", as there are thousands of tiny merge and fork points as the replicas went in and out of sync. While our traversal order optimisation code dramatically improves the performance in the asynchronous tests, it makes our concurrent tests slower. About 40% of the time spent replaying _friendsforever_ and _clownschool_ is simply spent preprocessing the graph looking for an ideal traversal order.

// TODO: Consider a graph for that.



// TODO: Do I include local editing performance numbers at all?
// #figure(
//   text(8pt, charts.speed_local),
//   caption: [
//     Comparative speed of DT and DT-crdt processing local editing events. The `_flat` variants of datasets here indicate that we're measuring the time taken to integrate all events assuming all edits in the data set happened linearly.
//   ],
//   kind: image,
// )


#figure(
  text(8pt, charts.all_speed_remote),
  caption: [
    xxx
    // Comparative speed of DT and DT-crdt algorithms processing remote data, measured in millions of run-length encoded events processed per second.
  ],
  kind: image,
) <chart-all-remote>


#figure(
  text(8pt, charts.all_speed_local),
  caption: [
    xxx
    // Comparative speed of DT and DT-crdt algorithms processing remote data, measured in millions of run-length encoded events processed per second.
  ],
  kind: image,
) <chart-all-local>


== Storage size

Our testing indicates that for text documents, event graphs usually take up less space on disk compared to storing the equivalent CRDT state. The reason is that editing positions in an event graph are represented in a more simple format - a single integer compared to (_originLeft_, _originRight_) for Fugue, FugueMax and YATA@Nicolaescu2016YATA or (_parentID_, _seq_) for RGA@Roh2011RGA.

For comparison, we have implemented an efficient event log format in the same style as the Yjs@yjs and Automerge@automerge CRDT libraries. The automerge file format is documented in detail here: @automerge-storage. We have done our best to do a like for like comparison of file size between different libraries, but this is tricky because every library works slightly differently, stores slightly different data and uses a different binary encoding scheme. In particular:

- The use of compression differs. Dt uses LZ4 compression on stored text content. Automerge uses GZIP compression on parts of the columnar format. And Yjs uses no compression at all. In our tests below we disable all compression.
- Unlike the other libraries, automerge also stores timestamp information for each event. In our tests we have set all timestamps to the unix epoch time.
- Yjs does not store any deleted content. This is a tradeoff - not storing deleted content results in a smaller file size and faster loading times. (The document state does not need to be regenerated.) However, earlier document states cannot be recomputed.
- Yjs does not store the causal parents of each operation.

We show the resulting file size with and without deleted character storage, for comparison with Automerge and Yjs respectively. See @chart-dt-vs-automerge and @chart-dt-vs-yjs.
// @chart-dt-vs-automerge and @chart-dt-vs-yjs compare the resulting filesize using our dt library with that of automerge and yjs respectively for some of our editing traces. In @chart-dt-vs-automerge our DT library is configured to match Automerge. In this case we store the text for all `Insert` events. In @chart-dt-vs-yjs our library is configured to match Yjs. In this test we only store the final document state.

#figure(
  text(8pt, charts.filesize_full),
  caption: [
    Relative file size storing the document using DT and Automerge. All events are stored in full, allowing the document to be reconstructed from any version. The filesize is shown relative to the total size of all inserted content in the event graph - which forms a lower bound.
    // File size to store the event graph using DT, and the equivalent CRDT state using automerge. The full event content is stored, allowing the document to be reconstructed at any version. The raw document size is the number of bytes in the final reconstructed document state after all events are merged. The insert length is the aggregate total number of bytes of inserted text in all events.
  ],
  kind: image,
) <chart-dt-vs-automerge>


#figure(
  text(8pt, charts.filesize_smol),
  caption: [
    Relative file size storing the event graph in DT and Yjs, compared to the size of the resulting (stored) document when all changes have been merged. Yjs only stores inserts which have not been deleted in the resulting document. DT is (equivalently) configured to store the final document snapshot. The content of inserted events is elided.
    // File size to store the event graph using DT, and the equivalent CRDT state using Yjs. Yjs only stores inserted content that was still present in the final document state. And DT, equivalently, includes a copy of the final document state itself.
  ],
  kind: image,
) <chart-dt-vs-yjs>


= Conclusion

Event graphs are a novel, exciting approach to building realtime collaborative editing applications. Our eg-walker algorithm builds on the foundation of existing CRDT based algorithms while alleviating some of the large downsides of CRDTs. In particular:

- Eg-walker doesn't need all replicating peers to store and load a large CRDT based state object into memory during collaborative editing sessions. This CRDT state object generally grows without bound, and pruning it is very difficult. Eg-walker only needs to access historical events when merging - and even then, like OT based systems, it only needs to access events back to the last common version.
- The file and network format used by CRDT based collaborative editing systems depends on the type definition of the CRDT state object. Different sequence based CRDTs (like Fugue@fugue, RGA@Roh2011RGA, YATA@Nicolaescu2016YATA and others) use different CRDT state formats. As a result, new CRDT algorithms require entirely new file formats and network formats to be written and deployed. By contrast, the event graph format is completely agnostic to the algorithm used to order concurrent edits.

Remarkably, eg-walker achieves this despite having excellent real-world performance. Even in our most complex data sets, we were able to merge over 1 million run-length encoded text editing events per second. When editing traces have linear causal histories, our system significantly outperforms all other approaches - as the CRDT machinery is completely unneeded.

We think this approach is a fascinating direction for future research in the field of realtime collaborative editing. We sincerely hope others build on this work, and find it as interesting and useful as we have.

#if not anonymous [
  #heading(numbering: none, [Acknowledgements])

  This work was made possible by the generous support from Michael Toomim, the Braid community and the Invisible College. None of this would have been possible without financial support and the endless conversations we have shared about collaborative editing.
]

#show bibliography: set text(8pt)
#bibliography(("works.yml", "works.bib"),
  title: "References",
  style: "association-for-computing-machinery"
)

#counter(heading).update(0)
#set heading(numbering: "A", supplement: "Appendix")

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


= Benchmark Setup

All benchmarks were run on a Ryzen 7950x CPU running Linux 6.2.0-39.

Rust code was compiled with `rustc v1.74.1` and compiled in release mode with `-C target-cpu=native`. Code is run on a single, pinned core for consistency.

Javascript was run using `nodejs v21.5.0`.

All time based measurements are based on the mean of at least 100 test iterations. All benchmark code and data is available on Github. We tested the following versions of all libraries:

#table(
  columns: (auto, auto, auto),
  align: (left, left, right, right, right, right),
  [*Library*], [*Language*], [*Version / Git Hash*],
  [Diamond Types (DT / DT-CRDT)], [Rust], [`7adf4bafeccb`],
  [Automerge], [Rust], [v 0.5.5],
  [Yjs], [Javascript], [v 13.6.10],
  [JSON-Joy], [Javascript], [`38392b30228a`],
  [Cola], [Rust], [v 0.1.1],
)

Cola with cursor optimisation removed is available at `https://github.com/josephg/cola-nocursors/`. //#link(https://github.com/josephg/cola-nocursors/).

/*
== Example optimised version_contains_ID function <example-localid-algorithm>

> Blah that section title.

This is an optimised function for checking if a version contains some local ID. Ie, this function checks if $i in ceil(V)$ for some event $i$ and some version $V$.

The algorithm does a bounded breadth first search within the event graph, checking events where:

- The event is within $ceil(V)$
- The local ID of the event is $>=$ the local ID of the search target.

For simplicity, the algorithm given below does not take advantage of run-length encoding. In our implementation, we also run-length encode all items in the event graph. This optimisation yields another large performance gain at the cost of some implementation complexity.

We have implemented a family of similar algorithms for querying the event graph, including functions to find the set difference, set union and set intersection between versions. See XXXX github.com/josephg/causal-graphs / diamond-types/src/cg/graph/tools.rs . TODO

```typescript
function versionContainsLocalId(graph: EventGraph, version: LocalID[], target: LocalId): boolean => {
  // Max heap. The highest local ID is removed first.
  let queue = new PriorityQueue<LocalID>()

  // Any ID < target is not relevant due to the ordering constraint.
  for (let id of version) {
    if (id == target) return true
    else if (id > target) queue.enq(id)
  }

  while (queue.length > 0) {
    let id = queue.deq()
    if (id === target) return true

    // Clear any other queue items pointing to this entry.
    while (queue.peek() == id) queue.deq()

    for (let p of graph.getParents(id)) {
      if (p === target) return true
      else if (p > target) queue.enq(p)
    }
  }

  return false
}

```

*/

/*
== Optimised diff function using local IDs <diff>

This is an optimised graph diff function. It computes the difference between the graphs $ceil(V_1)$ and $ceil(V_2)$, and returns the sets of event IDs that are only in $V_1$ and only in $V_2$.

This algorithm takes advantage of local IDs to compute the set difference efficiently.

For simplicity, the algorithm given here does not take advantage of run-length encoding. In our implementation, we also run-length encode all items in the event graph. This optimisation yields another large performance gain at the cost of some implementation complexity. See XXXX github.com/josephg/causal-graphs . TODO

```typescript
type LocalId = number // Local IDs are just integers.
enum Flag { V1Only, V2Only, Shared }

function diff(graph: EventGraph, v1: LocalId[], v2: LocalId[]) {
  // Max heap. The highest local ID is removed first.
  let queue = new PriorityQueue<(LocalId, Flag)>()

  // Number of items in the queue in both transitive histories (state Shared).
  let numShared = 0

  for (let id of v1) queue.push((id, Flag.V1Only))
  for (let id of v2) queue.push((id, Flag.V2Only))

  let v1Only = [], v2Only = []

  // Loop until everything is shared.
  while (queue.size() > numShared) {
    let (id, flag) = queue.pop()
    if (flag === Flag.Shared) numShared--

    // If the next item in the queue
    while (!queue.isEmpty() && queue.peek().0 == id) {
      let (_, flag2) = queue.pop() // Remove the item
      if (flag2 === Flag.Shared) numShared--;
      if (flag2 !== flag) flag = Flag.Shared
    }

    if (flag == Flag.V1Only) v1Only.push(id)
    if (flag == Flag.V2Only) v2Only.push(id)

    for (let p of graph.getParents(id)) queue.push((p, flag))
    if (flag == Flag.Shared) numShared += cg.getParents(id).length
  }

  return {v1Only, v2Only}
}

```

*/

/*
== The List formulation of FugueMax <list-fuguemax-code>

The function below is a reimplementation of the logic of FugueMax, expressed as a list insertion. See @fugue-list above for commentary.

```typescript
function integrate(ctx: EditContext, cg: causalGraph.CausalGraph, newItem: Item, cursor: DocCursor) {
  if (cursor.idx >= ctx.items.length || ctx.items[cursor.idx].curState !== ItemState.NotYetInserted) return

  let scanning = false
  let scanIdx = cursor.idx
  let scanEndPos = cursor.endPos

  let leftIdx = cursor.idx - 1
  let rightIdx = newItem.rightParent === -1 ? ctx.items.length : findItemIdx(ctx, newItem.rightParent)

  while (scanIdx < ctx.items.length) {
    let other = ctx.items[scanIdx]

    if (other.opId === newItem.rightParent) throw Error('invalid state')

    // The index of the origin left / right for the other item.
    let oleftIdx = other.originLeft === -1 ? -1 : findItemIdx(ctx, other.originLeft)
    if (oleftIdx < leftIdx) break
    else if (oleftIdx === leftIdx) {
      let orightIdx = other.rightParent === -1 ? ctx.items.length : findItemIdx(ctx, other.rightParent)

      if (orightIdx === rightIdx && causalGraph.lvCmp(cg, newItem.opId, other.opId) < 0) break
      else scanning = orightIdx < rightIdx
    }

    scanEndPos += itemWidth(other.endState)
    scanIdx++

    if (!scanning) {
      cursor.idx = scanIdx
      cursor.endPos = scanEndPos
    }
  }

  // We've found the position. Insert where the cursor points.
  ctx.insert(newItem, cursor)
}
```
*/
