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

Each device on which a user edits a document is a _replica_, and each replica stores the full editing history of the document.
When a user makes an insertion or deletion, that operation is immediately applied to the user's local replica, and then asynchronously sent over the network to any other replicas that have a copy of the same document.
Users can also edit their local copy while offline; the corresponding operations are then enqueued and sent when the device is next online.

Our algorithm makes no assumptions about the underlying network via which operations are replicated: any reliable broadcast protocol (which detects and retransmits lost messages) is sufficient.
For example, a relay server could store and forward messages from one replica to the others, or replicas could use a peer-to-peer gossip protocol.
We make no timing assumptions and can tolerate arbitrary network delay, but we assume replicas are non-Byzantine.

A key property that the collaboration algorithm must satisfy is _convergence_: any two replicas that have seen the same set of operations must be in the same state (i.e., a text consisting of the same sequence of characters), even if the operations arrived in a different order at each replica.
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
We describe the storage format in more detail in Section TODO.

== Document versions <versions>

Let $G$ be an event graph, represented as a set of events.
Due to convergence, any two replicas that have the same set of events must be in the same state.
Therefore, the document state (sequence of characters) resulting from $G$ must be $italic("replay")(G)$, where $italic("replay")$ is some pure (deterministic and non-mutating) function.
In principle, any pure function of the set of events results in convergence, although a $italic("replay")$ function that is useful for text editing must satisfy additional criteria (see @characteristics).

In order to correctly interpret an operation such as $italic("Delete")(i)$, we need to determine which character was at index $i$ at the time when the operation was generated.
Let $e_i$ be an event; the document state when $e_i$ was generated must be $italic("replay")(G_i)$, where $G_i$ is the set of events that were known to the generating replica at the time when $e_i$ was generated (not including $e_i$ itself).
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
The abstraction of an event graph allows us to reframe these algorithms in a simpler way: a collaborative text editing algorithm is a pure function $italic("replay")(G)$ of an event graph $G$.
This function can use the parent-child relationships between events, but concurrent events could be processed in any order.
This allows us to separate the process of replicating the event graph from the algorithm that ensures convergence.
In fact, this is how _pure operation-based CRDTs_ @polog are formulated, as discussed in @related-work.

In addition to determining the document state from an entire event graph, we need an _incremental update_ function.
Say we have an existing event graph $G$ and document state $italic("doc") = italic("replay")(G)$, and an event $e$ from a remote replica is added to the graph.
We could rerun the function to obtain $italic("doc")' = italic("replay")(G union {e})$, but it would be inefficient to re-process the entire graph.
Instead, we need to efficiently compute the operation that we need to apply to $italic("doc")$ in order to obtain $italic("doc")'$.
For text documents, this incremental update is also described as an insertion or deletion at a particular index; however, the index may differ from that in the original event due to the effects of concurrent operations, and a deletion may turn into a no-op if the same character has also been deleted by a concurrent operation.

Both OT and CRDT algorithms focus on this incremental update.
If there are no concurrent events, OT is straightforward: the incremental update is identical to the operation in the original event, as no transformation takes place.
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
Each replica stores the event graph on disk alongside the current state of the document.

Eg-walker performs a topological sort of the event DAG, as illustrated in @topological-sort, and then transforms each event so that if the transformed insertions and deletions are applied in topologically sorted order, starting with an empty document, the final document correctly represents the set of events processed.
The input of the algorithm is the event graph, and the output is this topologically sorted sequence of transformed operations.
In graphs with concurrent operations there are multiple possible sort orders, and eg-walker guarantees that the final document is the same, regardless which of these orders is chosen.

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

For example, the graph in @graph-example has two possible sort orders; eg-walker will either first insert the second "l" at index 3 and then the exclamation mark at index 5 (like User 1 in @two-inserts), or first insert "!" at index 4 followed by the second "l" at index 3 (like User 2 in @two-inserts); the final document is the same either way.
However, the choice of sort order affects the performance of the algorithm, as discussed in @complexity.

Event graph replay extends directly to incremental updates: when a new event is added to the graph, since all of its parents must already be in the graph, each added event becomes the next element of the topologically sorted sequence.
We can transform each new event in the same way as during replay, and apply the transformed operation to the current document state.
This way, the algorithm supports real-time collaboration.

== Characteristics of Eg-walker <characteristics>

Eg-walker ensures that the resulting document is consistent with Attiya et al.'s _strong list specification_ @Attiya2016 (in essence, replicas converge to the same state and apply operations in the right place), and it is _maximally non-interleaving_ @fugue (i.e., concurrent sequences of insertions at the same position are placed one after another, and not interleaved).

One way of achieving this goal would be to track the state of the document on each branch of the event graph, to translate each event into a corresponding CRDT operation (based on the document state in which that event was generated), and when branches in the event graph merge, to apply the CRDT operations from one branch to the other branch's state.
Essentially, this approach simulates a network of communicating CRDT replicas and their states.
However, doing this naively leads to poor performance, because the CRDT overhead is incurred on every operation.

Eg-walker is able to achieve much better performance by skipping the CRDT entirely in portions of the event graph that have no concurrency (which, in many editing histories, is the vast majority of the graph), and invoking the CRDT only during those portions with concurrency.
When processing an event that has no concurrent events, eg-walker is able to discard all of the CRDT state accumulated so far, keeping the data structure small.
A key insight of eg-walker is how to compute the correct transformed operations even though the CRDT state may reflect only a small part of the editing history.

Moreover, eg-walker requires the event graph and CRDT state only in order to transform an operation to account for concurrent events.
The algorithm does not inspect them when generating new events, or when adding an event to the graph that happened after all existing events.
This means that most of the time, the event graph can remain on disk without using any space in memory or any CPU time to load; it is sufficient to load only the latest document state, which can be stored in a separate file from the event graph.
We only have to load the event graph into memory when handling concurrency, and even then we only have to replay the portion of the graph since the last ancestor that the concurrent operations had in common.

Eg-walker's approach contrasts with the usual CRDT approach, which requires every replica to persist the CRDT state (including the unique ID for each character) to disk and send it over the network, and which requires that state to be loaded into memory in order to both generate and receive operations, even when there is no concurrency.
This can use significant amounts of memory and can make documents slow to load.

OT algorithms avoid the metadata overhead of CRDTs; similarly to eg-walker, they only need to persist the latest document state and the history of operations that may be concurrent to operations that might arrive in the future.
In both eg-walker and OT, the editing history/event graph can be discarded if we know that no event we may receive in the future will be concurrent with any existing event.
However, OT algorithms have asymptotically worse performance than eg-walker in transforming concurrent operations.

== Walking the event graph

For the sake of clarity we first explain a simplified version of eg-walker that replays the entire event graph, does not discard its CRDT state along the way, and incurs CRDT overhead even for non-concurrent operations.
In @clearing we show how to add the optimisation that allows us to replay only parts of the event graph.

First, we topologically sort the event graph in a way that keeps events on the same branch consecutive as much as possible: for example, in @topological-sort we first visit $e_"A1" ... e_"A4"$, then $e_"B1" ... e_"B4"$; we avoid alternating between branches, such as $e_"A1", e_"B1", e_"A2", e_"B2" ...$, even though that would also be a valid topological sort.
For this we use a standard textbook algorithm @CLRS2009: do a depth-first traversal, and build up the topologically sorted list in reverse order while returning from the traversal (i.e. after visiting events that happened later).
When choosing which branch to traverse, we use a greedy heuristic so that branches with fewer events tend to appear before branches with more events in the sorted order; this can improve performance but is not essential.

The algorithm then processes the events one at a time in topologically sorted order, updating a state object and outputting a transformed operation for each event.
The state object simultaneously captures the document at two versions: the version in which an event was generated (which we call the _prepare_ version), and the version in which all events seen so far have been applied (which we call the _effect_ version).
If the prepare and effect versions are the same, the transformed operation is identical to the original one.
In general, the prepare version represents a subset of the events of the effect version.
// Due to the topological sorting it is not possible for the prepare version to be later than the effect version.

The state object can be updated with three methods, each of which takes an event as argument:

/ Apply: Updates both the prepare version and the effect version to include the given event, assuming that the current prepare version equals the parents of that event, and that the event has not previously been applied. This method interprets the event in the context of the prepare version, and outputs the operation representing how the effect version has been updated.
/ Retreat: Updates the prepare version to remove the given event, assuming that the prepare version previously included that event.
/ Advance: Updates the prepare version to add the given event, assuming that the prepare version previously did not include that event, but the effect version did.

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
  caption: [An event graph. Starting with document "hi", one user changes "hi" to "hey", while concurrently another user capitalises the "H". After the users merge to the state "Hey", one of the users appends an exclamation mark to produce "Hey!".],
) <graph-hi-hey>

The effect version only moves forwards in time (through $italic("apply")$), whereas the prepare version can move both forwards and backwards.
Consider the example event graph in @graph-hi-hey, and assume that the events $e_1 ... e_8$ are traversed in order of their subscript.
These events can be processed as follows:

1. Start in the empty state, and then call $italic("apply")(e_1)$, $italic("apply")(e_2)$, $italic("apply")(e_3)$, and $italic("apply")(e_4)$. This is valid because each event's parent version is the set of all events processed so far.
2. Before we can apply $e_5$ we must rewind the prepare version to be $e_2$, which is the parent of $e_5$. We can do this by calling $italic("retreat")(e_4)$ and $italic("retreat")(e_3)$.
3. Now we can call $italic("apply")(e_5)$, $italic("apply")(e_6)$, and $italic("apply")(e_7)$.
4. The parents of $e_8$ are ${e_4, e_7}$; before we can apply $e_8$ we must therefore add $e_3$ and $e_4$ back into the prepare state again. We do this by calling $italic("advance")(e_3)$ and $italic("advance")(e_4)$.
5. Finally, we can call $italic("apply")(e_8)$.

In complex event graphs such as the one in @topological-sort it can be necessary to retreat and advance on the same event multiple times, but it is possible to process arbitrary DAGs this way.
The general rule is: apply the events in topologically sorted order, but before applying each event, compute $G_"old" = sans("Events")(V_p)$ where $V_p$ is the current prepare version, and $G_"new" = sans("Events")(e.italic("parents"))$ where $e$ is the next event to be applied.
We then call $italic("retreat")$ on each event in $G_"old" - G_"new"$ (in reverse order of their appearance in the topological sort), and call $italic("advance")$ on each event in $G_"new" - G_"old"$ (in topological sort order) before calling $italic("apply")(e)$.

== Representing prepare and effect versions <prepare-effect-versions>

The state object implements the $italic("apply")$, $italic("retreat")$, and $italic("advance")$ methods by maintaining a CRDT data structure.
This structure consists of a linear sequence of records, one per character in the document (runs of characters with consecutive IDs and the same properties can be run-length encoded to save memory).
A record is inserted into this sequence by $italic("apply")(e_i)$ for an insertion event $e_i$; subsequent deletion events and $italic("retreat")$/$italic("advance")$ calls may modify properties of the record, but records in the sequence are not removed or reordered once they have been inserted.

When the event graph contains concurrent insertion operations, we use an existing CRDT algorithm to ensure that all replicas place the records in this sequence in the same order, regardless of the order in which they traverse the event graph.
Any list CRDT could be used for this purpose; the main differences between algorithms are their performance and their interleaving characteristics @fugue.
Our implementation of eg-walker uses a variant of the Yjs algorithm @yjs @Nicolaescu2016YATA that we conjecture to be maximally non-interleaving; we leave a detailed analysis of this algorithm to future work, since it is not core to this paper.

Each record in this sequence contains the ID of the event that inserted the character, two integer state variables $s_p$ (the character's state in the prepare version) and $s_e$ (its state in the effect version), and any other fields required by the CRDT to determine the order of concurrent insertions.
$s_p$ and $s_e$ are zero if the character is visible (inserted but not deleted) in the prepare and effect version respectively; a positive integer indicates how many times that character has been deleted by concurrent delete events.
$s_p$ can also be -1 if the character has not yet been inserted in the prepare version, but $s_p$ cannot be less than -1 and $s_e$ cannot be negative.

The rules for updating $s_p$ and $s_e$ are:

- When a record is first inserted by $italic("apply")(e_i)$ with an insertion event $e_i$, it is initialised with $s_p = s_e = 0$.
- Calling $italic("apply")(e_d)$ with a deletion event $e_d$ increments both $s_p$ and $s_e$ in the record representing the deleted character.
- If $italic("retreat")(e_i)$ is called with an insertion event $e_i$, $s_p$ must be zero in the record affected by the event, and we move the affected character from $s_p = 0$ to $s_p = -1$. Conversely, $italic("advance")(e_i)$ moves from $s_p = -1$ to $s_p = 0$.
- If $italic("retreat")(e_d)$ is called with a deletion event $e_d$, $s_p$ must be positive in the record affected by the event, and $s_p$ is decremented. Conversely, $italic("advance")(e_d)$ increments $s_p$.

#figure(
  fletcher.diagram(node-stroke: 0.5pt,
    node((0.0,0), [_id_: 3\ _ch_: H\ $s_p$: 0\ $s_e$: 0]),
    node((0.6,0), [_id_: 1\ _ch_: h\ $s_p$: 1\ $s_e$: 1]),
    node((1.25,0), [_id_: 2\ _ch_: i\ $s_p$: 0\ $s_e$: 0]),
    node((2.9,0), [_id_: 3\ _ch_: H\ $s_p$: -1\ $s_e$: 0]),
    node((3.6,0), [_id_: 1\ _ch_: h\ $s_p$: 0\ $s_e$: 1]),
    node((4.25,0), [_id_: 2\ _ch_: i\ $s_p$: 0\ $s_e$: 0]),
    edge((1.8,0), (2.4,0), text(0.7em, $italic("retreat")(e_4)\ italic("retreat")(e_3)$), marks: "=>", thickness: 0.8pt, label-sep: 0.5em)
  ),
  placement: top,
  caption: [Left: the internal state after applying $e_1 ... e_4$ from @graph-hi-hey. Right: after $italic("retreat")(e_4)$ and $italic("retreat")(e_3)$, the prepare state is updated to mark "H" as "not yet inserted" (–1), and the deletion of "h" is undone. The effect state is unchanged.]
) <crdt-state-1>

For example, @crdt-state-1 shows the state after applying $e_1 ... e_4$ from @graph-hi-hey, and how that state is updated by retreating $e_4$ and $e_3$ before $e_5$ is applied.
In the effect state, the lowercase "h" is marked as deleted, while the uppercase "H" and the "i" are visible.
In the prepare state, by retreating $e_4$ and $e_3$ the "H" is marked as not yet inserted ($s_p = -1$), and the deletion of "h" is undone ($s_p = 0$).

#figure(
  fletcher.diagram(node-stroke: 0.5pt,
    node((0.0,0), [_id_: 3\ _ch_: H\ $s_p$: 0\ $s_e$: 0]),
    node((0.7,0), [_id_: 1\ _ch_: h\ $s_p$: 1\ $s_e$: 1]),
    node((1.4,0), [_id_: 6\ _ch_: e\ $s_p$: 0\ $s_e$: 0]),
    node((2.1,0), [_id_: 7\ _ch_: y\ $s_p$: 0\ $s_e$: 0]),
    node((2.8,0), [_id_: 8\ _ch_: !\ $s_p$: 0\ $s_e$: 0]),
    node((3.5,0), [_id_: 2\ _ch_: i\ $s_p$: 1\ $s_e$: 1])
  ),
  placement: top,
  caption: [The internal eg-walker state after replaying all of the events in @graph-hi-hey.]
) <crdt-state-2>

@crdt-state-2 shows the state after replaying all of the events in @graph-hi-hey: "i" is also deleted, the characters "e" and "y" are inserted immediately after the "h", $e_3$ and $e_4$ are advanced again, and finally the exclamation mark is inserted after the "y".
The figures include the character for the sake of readability, but the algorithm actually does not need to store characters in its internal state.

== Mapping indexes to character IDs

In the event graph, insertion and deletion operations specify the index at which they apply; in order to update eg-walker's internal state, we need to map these to the correct record in the sequence.
Moreover, to produce the transformed operations, we need to map these internal IDs back to indexes again.

A simple but inefficient algorithm would be: to apply a $italic("Delete")(i)$ operation we iterate over the sequence of records and pick the $i$th record with a prepare state of $s_p = 0$ (i.e., the $i$th among the characters that are visible in the prepare state, which is the document state in which the operation should be interpreted).
Similarly, to apply $italic("Insert")(i, c)$ we skip over $i - 1$ records with $s_p = 0$ and insert the new record after the last skipped record (if there have been concurrent insertions at the same position, we may also need to skip over some records with $s_p = -1$, as determined by the list CRDT's insertion ordering).

To reduce the cost of this algorithm from $O(n)$ to $O(log n)$, where $n$ is the number of characters in the document, we construct a B-tree whose leaves, from left to right, contain the sequence of records representing character states.
We extend the tree into an _order statistic tree_ @CLRS2009 (also known as _ranked B-tree_) by adding two integers to each node: the number of records with $s_p = 0$ contained within that subtree, and the number of records with $s_e = 0$ in that subtree.
Every time the state variables are updated, we also update those numbers on the path from the updated record to the root.
As the tree is balanced, this can be done in $O(log n)$ time.

Now it is easy to find the $i$th record with $s_p = 0$ in logarithmic time by starting at the root of the tree, and adding up the values in the subtrees that have been skipped.
Moreover, once we have a record in the sequence we can efficiently determine its index in the effect state by going in the opposite direction: working upwards in the tree towards the root, and summing the numbers of records with $s_e = 0$ that lie in subtrees to the left of the starting record.
This allows us to efficiently transform an operation from the prepare version into the effect version.
If the character was already deleted in the effect version ($s_e > 0$), the transformed operation is a no-op.

We use this process on every $italic("apply")(e)$, and then store the ID of the target record on the event $e$ in the event graph.
For insertions, this is simply the ID of the event itself; for deletion events, it is the ID of the event that originally inserted the character being deleted.
When we subsequently perform a $italic("retreat")(e)$ or $italic("advance")(e)$, that event $e$ must have already been applied, and therefore we must have previously stored the ID of the record it refers to.
We can therefore ignore the operation index when retreating and advancing, and instead use the ID to look up the record to be updated.
To this end we maintain a second B-tree that is keyed by event ID, and which points at the leaf nodes of the first B-tree.
This tree allows us to advance or retreat in logarithmic time.

== Clearing CRDT state <clearing>

As described so far, the algorithm retains every insertion since document creation forever in its internal state, causing the state to become big, and requiring the entire event graph to be replayed in order to restore the state.
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

These optimisations make it very fast to process documents that are mostly edited sequentially (e.g., because the authors took turns and did not write concurrently), since most of the event graph of such a document is a linear chain of critical versions.

If a replica receives events that are concurrent with existing events in its graph, but the replica has already discarded its internal state resulting from those events, it needs to rebuild some of that state.
It can do this by identifying the most recent critical version that happened before the new event, replaying the existing events that happened after that critical version (in topologically sorted order), and finally applying the new events.
Events from before that critical version do not need to be replayed.
Since most editing histories have critical versions from time to time, this means that usually only a small subset of the event graph needs to be replayed.
The root version $emptyset$ is always a critical version, so in the worst case this algorithm replays the entire event graph.

== Partial event graph replay <partial-replay>

Assume that we want to add event $e_"new"$ to the event graph $G$, that $V_"curr" = sans("Version")(G)$ is the current document reflecting all events except $e_"new"$, and that $V_"crit" eq.not V_"curr"$ is the latest critical version in $G union {e_"new"}$ that happened before both $e_"new"$ and $V_"curr"$.
Further assume that we have discarded the internal state, so the only information we have is the latest document state at $V_"curr"$ and the event graph; in particular, without replaying the entire event graph we do not know the document state at $V_"crit"$.

However, a key insight of eg-walker is that the full document state at $V_"crit"$ is not needed; all we need is enough state to transform $e_"new"$ to apply to the document at $V_"curr"$, and this state can be obtained by replaying only the events since $V_"crit"$, that is, $G - sans("Events")(V_"crit")$, in topologically sorted order.
For example, using the graph in @topological-sort, say the current state is $G = {e_"A1" ... e_"A5", e_"B1" ... e_"B4"}$, so $V_"curr" = {e_"A5", e_"B4"}$, and the new event $e_"new" = e_"C1"$.
Then ${e_"A1"}$ is the most recent critical version.

Before replaying the events, we initialise the internal state with a single placeholder record that represents the range of indexes $[0, infinity]$ of the document state at $V_"crit"$ (we do not know the exact length of the document at that version, but we can still have a placeholder for arbitrarily many indexes).
Placeholders are counted as the number of characters they represent in the order statistic tree construction, and they have the same length in both the prepare and the effect versions.
We then apply events as follows:

- Applying an insertion at index $i$ creates a record with $s_p = s_e = 0$ and the ID of the insertion event. We map the index to a record in the sequence using the prepare state as usual; if $i$ falls within a placeholder for range $[j, k]$, we split it into a placeholder for $[j, i-1]$, followed by the new record, followed by a placeholder for $[i, k]$. Placeholders for empty ranges are omitted.
- Applying a deletion at index $i$: if the deleted character was inserted prior to $V_"crit"$, the index must fall within a placeholder with some range $[j, k]$. We split it into a placeholder for $[j, i-1]$, followed by a new record with $s_p = s_e = 1$, followed by a placeholder for $[i+1, k]$. The new record has a placeholder ID that only needs to be unique within the local replica, and need not be consistent across replicas.
- Applying a deletion of a character inserted since $V_"crit"$ updates the record created by the insertion.

Before applying an event we retreat and advance as before.
The algorithm never needs to retreat or advance an event that happened before $V_"crit"$, therefore we can rely on every retreated or advanced event to have a record ID that was assigned when we applied the event.

While replaying events in $G$ we do not output transformed operations.
When we have completed replaying up to $V_"curr"$, we next retreat/advance to the parent version of $e_"new"$, apply $e_"new"$, and output a transformed version of that event.
We do this in the same way as before, by starting at the updated record and then moving upwards in the B-tree, adding up the preceding number of characters in the effect version (including placeholders).
Events subsequent to $e_"new"$ can now be processed using the state we constructed, without having to repeat the replay.

If there are concurrent insertions at the same position, we invoke the CRDT algorithm to place them in a consistent order as discussed in @prepare-effect-versions.
Since all concurrent events must be after $V_"crit"$, they are included in the replay.
When we are seeking for the insertion position, we never need to seek past a placeholder, since the placeholder represents characters that were inserted before $V_"crit"$.

== Algorithm complexity <complexity>

Say we have two users who have been working offline, generating $k$ and $m$ events respectively.
When they come online and merge their event graphs, the latest critical version is immediately prior to the branching point.
If the branch of $k$ events comes first in the topological sort, the replay algorithm first applies $k$ events, then retreats $k$ events, applies $m$ events, and finally advances $k$ events again.
Asymptotically, $O(k+m)$ calls to apply/retreat/advance are required regardless of the order in which the branches are traversed, although in practice the algorithm is faster if $k<m$ since we don't need to retreat/advance on the branch that is visited last.

Each apply/retreat/advance requires one or two traversals of the order statistic tree, and at most one traversal of the ID-keyed B-tree.
The upper bound on the number of entries in each tree (including placeholders) is $2(k+m)+1$, since each event generates at most one new record and one placeholder split.
Since the trees are balanced, the cost of each traversal is $O(log(k+m))$.
Overall, the cost of merging branches with $k$ and $m$ events is therefore $O((k+m) log(k+m))$.

To determine the worst-case complexity of replaying an event graph with $n$ events, note that each event is applied exactly once, and before each event we can at most retreat or advance each prior event once.
The overall worst-case complexity of the algorithm is therefore $O(n^2 log n)$; however, this case is unlikely to occur in realistic collaborative text editing scenarios.

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


= Event Graphs

TODO: old material in this section, to be edited

Formally, the event graph $G$ is a set of globally unique event IDs ${i_1, i_2, i_3, ..}$ as well as associated event data $e_i$ and parent version $P_i$ for each event in the graph, where:

//, each of which has a corresponding event $e_i$ and parent set $P_i$.

/ $i_n$: is a globally unique ID. IDs must be comparable (fully ordered) for tie breaking.
/ $e_i$: is the original editing event that occurred. For text editing, this is either *Insert(pos, content)* or *Delete(pos)*. Events have an associated _apply function_ $plus.circle$ which applies the event to a document. For example, $\""AB"\" plus.circle italic("Insert")(1, \"C\") = \""ACB"\"$
/ $P_i$: is a set of ids ($P_i subset G$) of other events which _happened-before_ $e_i$. The parents set is stored in a transitively reduced form. // $forall a in P_b: e_a -> e_b$

The _happened-before_ relationship $->$ can be extended to versions and events:

- Event $i$ _happened-before_ version $V$ if $i$ is within the event graph described by $V$. Ie, $i -> V$ iff $i in ceil(V)$.
- Given two versions $V_1$ and $V_2$, $V_1 -> V_2$ iff $ceil(V_1) subset ceil(V_2)$.// (Or, equivalently, $V_1 != V_2 and forall i_1 in ceil(V_1): i_1 -> V_2$).
// - Versions $V_1$ and $V_2$ are concurrent (written $V_1 || V_2$) iff $V_1 arrow.r.not V_2 and V_2 arrow.r.not V_1$.


== Critical Versions <critical-version>

A  _critical version_ is any version $V$ in event graph $G$ which cleanly partitions $G$ into 2 distinct subsets of events: the events in or before $V$, and the events after $V$.

Intuitively, critical versions represent moments at which all editing peers synchronised before making any future edits.

#definition("Critical versions")[
  Formally, we say a version $V$ in event graph $G$ is a _critical version_ if it separates all events in $G$ into two disjoint subsets $ceil(V)$ and $T$ where $T = G - ceil(V)$ such that all events in $ceil(V)$ _happened-before_ all events in $T$. Ie, $forall i_1 in ceil(V), i_2 in T: i_1 <- i_2$.

  Equivalently, a version $V$ is a _critical version_ in graph $G$ if $G$ does not contain any events concurrent with $V$. Ie, $exists.not i in G: i || V$.
]

// Note that a version may be critical

Some observations about critical versions:

- A version is only a critical version in the context of a specific event graph. If $V$ is critical in $G$, it may not be critical in event graph $G union {i}$, as $i$ may be concurrent with $V$.
- The empty set $emptyset$ and $ceil(G)$ are always critical versions in any event graph $G$. They split $G$ into $(emptyset, G)$ and $(G, emptyset)$ respectively.
- All critical versions in an event graph are fully ordered by $->$. If $V_1$ and $V_2$ are distinct critical versions in $G$, either $V_1 -> V_2$ or $V_2 -> V_1$.

#figure(
  fletcher.diagram(
    spacing: (5mm, 5mm),
    // node-stroke: 0.5pt,
  {
    let (r, a, b, c, d) = ((0, 1), (0, 0), (-1, -1), (1, -1), (0, -2))
    let (e, f, g) = ((-1, -3), (1, -3), (0, -4))
    // node(r, $emptyset$)

    node(a, $A$)
    node(b, $B$)
    node(c, $C$)
    // node(d, $circle.small$)
    node(e, $E$)
    node(f, $F$)
    node(g, $G$)

    // edge(r, a, "->")

    edge(a, b, "->")
    edge(a, c, "->")
    // edge(b, d, "->")
    // edge(c, d, "->")
    // edge(d, e, "->")
    // edge(d, f, "->")
    // edge(c, d, "->")

    edge(b, e, "->")
    // edge(b, f, "->")
    edge(c, e, "->")
    edge(c, f, "->")

    edge(e, g, "->")
    edge(f, g, "->")

    edge((-2.5, 1), r, "..")
    edge(r, (2.5, 1), "..")

    edge((-2.5, 0), a, "..")
    edge(a, (2.5, 0), "..")

    edge((-2.5, -3), e, "..")
    edge(e, f, "..")
    edge(f, (2.5, -3), "..")
    // edge((-2.5, -2), d, "..")
    // edge(d, (2.5, -2), "..")

    edge((-2.5, -4), g, "..")
    edge(g, (2.5, -4), "..")
  }),
  caption: [An example event graph with 4 critical versions: $emptyset$, $A$, ${E, F}$ and $G$ shown as dotted horizontal lines. Version ${B, C}$ is not a critical version as ${B, C} || F$.]
) <crit-example>

// === Greatest Common Version <gcv>

// Consider 2 versions $V_1$, $V_2$, and the event graph $G$ containing all events in either version: $G = ceil(V_1) union ceil(V_2)$. We define the _greatest common version_ $C = V_1 sect.sq.double V_2$ on $G$ such that:

// - All events in $C$ are in both $V_1$ and $V_2$. Ie, $C subset.eq V_1 and C subset.eq V_2$. // $forall i in C: i in ceil(V_1) and i in ceil(V_2)$
// - C is a critical version (defined above)
// - C is the "greatest" version meeting the aforementioned criteria. (If versions $C_1$ and $C_2$ both meet the above criteria, and $C_1 -> C_2$, $C_2$ is chosen as the greatest common version).

// The greatest common version is well defined for any two versions because:

// - The root version $emptyset$ is a critical version in every event graph
// - All of the critical versions in a graph are fully ordered

// // > DIAGRAMS?

// Note the greatest common version is sometimes distinct from the greatest lower bound (GLB) of a pair of versions. For example, In @crit-example above, the GLB of versions $B$ and $D$ is version $B$. However, the greatest common version $B sect.sq.double D = A$

/*
== Replication

> TODO: Consider removing this section

The network needs to eventually deliver all events to all replicas in the set of peers. We can do that by treating the event graph in turn as a Grow-Only Set CRDT of event triples $(i, e_i, P_i)$. Using the notation from @Shapiro2011:

- The state $s$ is the event graph $G$, defined above.
- $s^0$ is the empty set $emptyset$
- _prepare_ is the identity function. Events are preserved as-is.
- _effect_ performs set union $union$, adding all received items to the local set.
- Events must be merged in _causal order_, preserving the invariant that an item cannot be added to the set until all of its parents are in the set. Formally, the delivery precondition $P$ is defined by $P(s, (i, e_i, P_i)) := P_i subset.eq s$. This property can be trivially guaranteed by requiring the network protocol to transmit events between peers in causal order.
- The query function $q$ needs to transform the event graph into its corresponding document state. Almost all the complexity of this approach resides in this function, and we will spend most of the rest of this paper discussing it.

> Diagrams - example REGs.
*/

== Replay function

Users don't want the event graph. They want to see the resulting document itself. To generate the document state, event graphs can be _replayed_ (via a _replay function_) to generate the corresponding document state, after all events in the graph have been merged.

// The remaining piece is defining a system's _replay function_ $r$, which calculates the corresponding document state generated by replaying a graph of events.

// #definition("Document state")[
//   We define $DD$ as the set of all possible _document states_ for some system. For text documents, this is the set of all strings.
// ]

#definition("Replay function")[
  The _replay function_ is defined as $r : V => DD$. The replay function converts an event graph into the corresponding document state $d in DD$. The event graph is specified via its version - ie, $G = ceil(V)$.

  $DD$ is the set of all possible document states in our system.

  The initial document state $d_0 in DD$ corresponds to the document state before any events have occurred. $d_0 = r(emptyset)$.

  For text editing, $DD$ is the set of all text documents. $d_0$ is the empty string `""`.
]

// Recall that the event graph is a record of the edits made by a set of peers collaboratively editing a document. The replay function answers the question of: given the set of edits described by $G$, what should the resulting document look like?

// The job of the replay function is to calculate the eventual document state made by this network of peers after the system has reached quiescence.

// Interestingly, we have a great deal of freedom when defining this replay function.
Replay functions can differ in both semantics and implementation. Semantically different replay functions produce different document states for the same set of events. Different implementations may produce the same result, but they will do so via different algorithms with different performance characteristics.

// We can implement this function in a variety of different ways.

// As shown in [Time machines paper],
We can define a replay function's behaviour by constructing it from the definition of an existing CRDT:

#definition("CRDT based replay function")[
  We can define a replay function from a CRDT definition. Consider a network of collaborating replicas which are using a CRDT to create and replicate the events described by the event graph $G$. Once this network of peers has reaches quiescence, all peers will have converged on some document state. $r(G)$ must emit this document state.

  More formally, assume we have some CRDT defined as $(S, s^0, q, t, u, P)$ via @Shapiro2011. $S$ and $s^0$ are the state domain and initial state, respectively. $q$ is the _query_ function, $t$ is the _prepare_ function and $u$ is the _effect_ function.

  Let $c: G => S$ be a function which generates the corresponding CRDT state for any event graph. $c$ is defined such that:

  - $c(emptyset) = s^0$
  - We can iteratively add events to the CRDT state by using the CRDT's prepare and effect functions, though they must be added in order. $forall G, i : P_i subset G, c(G union {i}) = u(c(G), t(e_i, c(G)))$

  The replay function emits the equivalent CRDT state $c(G)$, passed through the CRDT's replay function:

  $ r(G) := q(c(G)) $

  // $r(G)$ must produce the same document state as the CRDT does. $r(G) = q(s)$ where $q(s)$ is the CRDT's state passed to the CRDT's query function.
] <crdt-equivalence>

A haskell implementation of this algorithm is provided in @generic-crdt-replay.

// Implemented this way, the replay function does same work as the CRDT, by:

// 1. Replaying all events to generate the corresponding CRDT state
// 2. Running the generated CRDT state through the CRDT's query function


Unfortunately, this algorithm is slow and memory inefficient in practice:

> BENCHMARK

Worse, it must generate the CRDT state on every peer (instead of once, across the whole network). And it must either regenerate the CRDT state on every incoming edit (which would be horribly slow), or cache the CRDT state locally (which removes any benefit from using event graphs in the first place).


// We can implement _replay_ based on a CRDT by simulating a network of collaborating peers directly. See @generic-crdt-replay.

// However, because the corresponding CRDT state is not actually visible outside the replay function, it does not actually need to be generated.

// In CRDT literature (eg @Shapiro2011), the replay function's output corresponds to the output of the CRDT's _query function_ ($q$) when run on the CRDT state implied by the event graph. However, $r$ accepts as input the set of all original events, not the corresponding CRDT state. Thus, our replay function must also effectively perform all the work of the equivalent CRDT's _prepare_ and _effect_ functions on the entire event graph.

// We can implement this function in a variety of different ways. But the most obvious approach is to construct $r$ from an existing CRDT, and have it simulate the corresponding network of collaborating peers making changes to the document. This approach was described in [time machines], and simple algorithm to do so is provided in [appendix X]. However, implemented this way, this process replicate the computation of the entire collaborating network on every peer on that network. Naively implemented, it multiplies CPU and memory requirements for every peer by the number of peers on the network.

// Whether this event graph approach is desirable depends on our ability to make the replay function fast.

The performance - and by extension practical viability - of this approach to building collaborative editing systems depends on our ability to make the replay function perform well. As we will show in @benchmarking, the eg-walker replay function introduced in this paper performs very well in practice.


=== Transform function <transform>

> TODO: Consider moving this inside the eg-walker section.

Discussion of operation transformation is curiously absent from most of the CRDT literature, given how useful it is when building practical systems. Most text editing CRDT algorithm papers (@fugue, [RGA], etc) describe user content embedded directly inside the CRDT's data structure. CRDTs are defined in @Shapiro2011 with a simple query function $q: S => DD$ which emits a bulk copy of the new document state.



// This sort of approach is impractical and inefficient. Text editor applications already use exotic, internal data structures to store the document contents. For example, VS Code uses a "Piece Tree" @vscode-buffer in order to efficiently support complex editing features like syntax highlighting and multi-cursor editing. If the document buffer was replaced en masse, the text editor would need to recompute its syntax highlighting information (which may be computationally very expensive). Worse, the local user's cursor position would be lost.

Instead, we define a _partial transform_ function $T(V_0, V_m)$. This function outputs a list of _transformed_ events (or operations) $e_1, e_2, ...$ that can be applied to a document at some version $V_0$ in order to modify it to the merged document state at version $floor(V_0 union V_m)$. The transform function is denoted $T(V_0, V_m) = [e_1, e_2, ...]$.

There are several benefits to this:

+ Text editors usually use their own exotic internal data structures to store the document's content. These data structures are optimised for fine grained, incremental updates. For example, VS Code uses a "Piece Tree" @vscode-buffer in order to efficiently support complex editing features like syntax highlighting and multi-cursor editing. Replacing the entire editing buffer whenever remote editing events are received when would inefficiently force the editor to recompute syntax highlighting information across the whole document.
+ The local user's cursor position may need to be updated. Fine grained updates allow this.
+ Transformed events can often be calculated with little or no reference to earlier events in the event graph. Defining our system in terms of a partial transform function allows many optimisations to be made that would not otherwise be possible. For example, incremental per-character updates during live editing sessions, and pruning (or archiving) old events. This is explored in much more detail in @eg-partial below.

The transformed operations must match the semantic behaviour of the replay function. Formally:

// $ r(ceil(V_0)) plus.circle e_1 plus.circle e_2 plus.circle ... = r(ceil(V_0 union V_m)) $
$ r(V_0) plus.circle T(V_0, V_m) = r(V_0 union V_m) $

(where $plus.circle$ is the event application operator.)

Substituting $r(emptyset) = d_0$, the replay function can also be implemented in terms of $T$:

$ forall V: r(V) = d_0 plus.circle T(emptyset, V) $

Thus, the partial transform function is the only function we need to implement.

// This has an additional benefit for algorithms like eg-walker: Ideally, transformed events can be calculated with little or no reference to earlier events in the event graph. Defining our system in terms of a partial transform function allows many optimisations to be made that would not otherwise be possible. For example, when an editing trace is completely sequential, the transform function doesn't need to do any work at all - it just returns the events in $V_m - V_0$ in causal order. This also paves the way for pruning (or archiving) old events.

// These optimisations are explored in detail in @eg-partial.




/*
=== Correctness <correct>

As shown in [Time machines paper], we can define a replay function's behaviour by constructing it from the definition of an existing CRDT.

Consider a network of collaborating replicas using a CRDT to create and replicate the events described by the event graph $G$. Once this network of peers has reaches quiescence, all peers will have converged on some document state. $r(G)$ must produce the same document state as the CRDT.

In @generic-crdt-replay we list a simple simulation algorithm which implements a replay function in this way, given the set of functions defining a CRDT.

While mathematically useful, this approach is unfortunately not practical for collaborative text editing because:

- It is impractically slow and memory inefficient when merging large text editing traces (See @benchmarking for details.)
- It is unclear how a partial transform function can be derived from a simulation algorithm defined in this way.

In @eg-walker, we define the eg-walker algorithm. Eg-walker matches the semantic behaviour of the FugueMax sequence CRDT, while overcoming these shortcomings.

*/

// Delightfully, so long as a network of peers coordinate on the semantic _definition_ of their replay function, they are free to diverge when it comes to their _implementation_ of that function. Just like different C compilers are compatible if they produce equivalent executable files given the same source code, in a network of replicas collaboratively editing a document, those replicas can have totally different _implementations_ so long as their replay functions behave the same for all input.

// We consider replayable event graphs to be somewhat useless in practice if they do not perform as well as their equivalent CRDTs.

// In order to make use of replayable event graphs in practical, useful software, we need a way to replay event graphs.

// Without a _partialTransform_ function, every event will either require every peer to re-compute the entire CRDT state (from the very first event), or locally cache the corresponding CRDT state - which negates many of the advantages of using an event graph over a CRDT in the first place.


= Introducing Eg-walker: FugueMax for Event Graphs <eg-walker>

In this chapter we present the _eg-walker_ (Event Graph Walker) algorithm. Eg-walker is a novel algorithm for efficiently replaying sequence editing event graphs, using the semantics of the FugueMax CRDT @fugue.

Eg-walker is:

// For replayable event graphs to be used in place of CRDTs in collaborative text editing, they must not only be well defined and correct but also demonstrate comparable performance to existing CRDT based solutions.


/ Correct: _eg-walker_ matches the behaviour of the FugueMax CRDT (@fugue), as per @crdt-equivalence. FugueMax is a proven and modern sequence CRDT free of interleaving issues.
/ Performant: The performance of _eg-walker_ is competitive with leading CRDT implementations.
/ Supports partial transformation: The algorithm includes a partial transformation function, enabling efficient integration of changes into a document snapshot (for example, a text editing buffer).

In this paper we show a construction of eg-walker matching the semantics of FugueMax. However, we believe eg-walker can also be adapted to match the semantics of most other sequence CRDTs with relative ease. We have implemented variants based on Yjs and Fugue with minimal code changes. These variants will not be discussed in this paper.

We have done extensive performance optimization and tuning on our implementation. @benchmarking shows detailed benchmarking results, comparing eg-walker to other approaches.

A working typescript implementation of eg-walker is provided in our _reference-reg_ repository @reference-reg. This library is fully featured, but missing many optimisations in order to keep the code simple and easy to understand. We also provide a much more fully featured implementation of eg-walker in our _diamond types_ repository @dt. This is the implementation benchmarked in @benchmarking.

== High level overview

// Blergh.
// Events are defined in the typical way for a sequence CRDT. Each event is one of:

At a high level, eg-walker is an algorithm for efficiently converting graphs of text editing events (inserts and deletes) into actual text documents.

We define editing events in the same way as in the Fugue paper. Each event is one of:

/ _insert(p, x)_: inserts (splices) in a new element with the value $x$ at position $p$ in the document, between existing elements at index $p-1$ and index $p$. For text documents, each element will typically be a unicode scalar value.
/ _delete(p)_: deletes the element at position $p$. Later elements are shifted to fill the gap.

Like FugueMax, our system does not support replace or move operations.

#let vp = $V_italic("p")$
#let ve = $V_italic("e")$
#let sp = $s_italic("p")$ // don't want to replace 'sin'.
#let se = $s_italic("e")$ // don't want to replace 'sin'.

Eg-walker performs an in-order traversal of the event graph. During this traversal, eg-walker iteratively builds a temporary, in-memory instance of Fugue's internal state in order to merge concurrent changes. The state contains some minor departures from Fugue, which are described below.

The traversal iteratively visits all events in the event graph in some _causal order_. That is, if the graph contains events $i_1$ and $i_2$ such that $i_1 -> i_2$, the traversal must visit $i_1$ before $i_2$.

As each event is visited, we:

+ Adjust the local state to resemble the event's parent version.
+ Use FugueMax's _prepare_ function to compute the equivalent FugueMax CRDT message.
+ Merge the CRDT message into the local state (using FugueMax's _effect_ function). In the process, we calculate and emit the resulting transformed event.

// Each of these steps will be described in more detail below. We

// When the CRDT message is merged in to the local state, the state is used to transform the message into a _transformed operation_ (a la [time machine paper]).

The stream of transformed operations can be used directly, or combined in order to compute the resulting document state after all changes have been merged. As described in [time machines], the ability to generate transformed operations is not a unique property of eg-walker. FugueMax can be modified to support this capability directly.

Some events may be elided entirely from the transformed output stream (or replaced with no-ops). This may happen when the event graph contains multiple events which concurrently delete the same item.

In pseudocode:

```
function transformAllEvents(graph) -> Iterator<TransformedOperation> {
  state := new EgWalkerState()

  for event (i, e, p) in graph.inOrderTraversal() {
    state.setPrepareVersion(p)
    message := state.prepare(i, e)
    op := state.effect(message)

    yield(op)
  }
}

function replay(graph) -> Document {
  doc := []
  for op in transformAllEvents(graph) {
    doc.apply(op)
  }
  return doc
}
```

The _prepare_ and _effect_ functions mirror FugueMax. _setPrepareVersion_ is described in @prepareversion below.

The algorithm listed above processes _all_ events in the event graph. @eg-partial generalises the algorithm to support _partial replay_. This allows implementations to efficiently merge recent events into an existing document snapshot. //In section [xxx], we describe how the algorithm can be generalised to support partial updates.

=== Algorithm Example

For example, consider an event graph containing the following set of events:

```
{id: A, event: Insert('A', 0), parents: []}
{id: B, event: Insert('B', 1), parents: [A]}
{id: C, event: Insert('C', 1), parents: [A]} // <-- Concurrent with B!
{id: D, event: Insert('D', 2), parents: [B, C]} // Inserted between B and C.
```

#figure(
  fletcher.diagram(
    // cell-size: 1mm,
    spacing: (8mm, 8mm),
    // node-stroke: black + 0.5pt,
    node-stroke: 0.5pt,
    // node-shape: rectangular,
    // debug: 1,
    // node-fill: blue.lighten(90%),
  {
    let (a, b, c, d) = ((0, 0), (-1, -1), (1, -1), (0, -2))
    node(a, $A$)
    node(b, $B$)
    node(c, $C$)
    node(d, $D$)
    edge(a, b, bend: -10deg, "->")
    edge(a, c, bend: 10deg, "->")
    edge(b, d, bend: -10deg, "->")
    edge(c, d, bend: 10deg, "->")
  }),
  caption: [Example event graph]
) <eg-simple>

In order to compute the resulting document state, eg-walker traverses the events in some causal order. In this case the traversal will either be in order $[A, B, C, D]$ or $[A, C, B, D]$, chosen arbitrarily. During traversal, events are converted into FugueMax CRDT events using the CRDT's _prepare_ function, producing the equivalent FugueMax messages:

```
{id: A, originLeft: (start), originRight: (end), x: 'A'}
{id: B, originLeft: A,       originRight: (end), x: 'B'}
{id: C, originLeft: A,       originRight: (end), x: 'C'}
{id: D, originLeft: B,       originRight: C,     x: 'D'}
```

These messages are merged into a local FugueMax tree, with state "ABCD". (Assuming item B is sorted before item C). The corresponding left-origin FugueMax tree shown in @fuguemax-simple.

#figure(
  fletcher.diagram(
    cell-size: 0mm,
    spacing: (4mm, 4mm),
  {
    let (start, a, b, c, d) = ((0,0), (1,-1), (2, -2), (4, -2), (3, -3))
    node(start, [_start_])
    node(a, $A$)
    node(b, $B$)
    node(c, $C$)
    node(d, $D$)
    edge(start, a, "-")
    edge(a, b, "-")
    edge(b, d, "-")
    edge(a, c, "-")
  }),
  caption: [Left-origin FugueMax tree of this data set]
) <fuguemax-simple>

#claim[
  *Claim:* The CRDT messages (and the final document state) will be entirely independent of traversal order. // This follows from the CRDT's commutativity property.
]

As each CRDT message is merged in, the resulting transformed position of each event is computed based on the position of the inserted or deleted item in the tree. In this example, assuming the events are visited in order of $[A, B, C, D]$, the list of transformed operations would look like this:

```
{id: A, event: Insert('A', 0)}
{id: B, event: Insert('B', 1)}
{id: C, event: Insert('C', 2)} // <-- Note the position has changed!
{id: D, event: Insert('D', 2)}
```

These transformed events can be applied in order to an empty document to produce the final document state (again, "ABDC").

// The order of transformed events - and their transformed positions - depends on the chosen traversal order.
If events were processed in a different order (eg $[A, C, B, D]$), the transformed operations would be slightly different, but the resulting document after applying them ("ABDC") would stay the same.
//not only would the output order change, but the transformed positions would also change (In this case, C would be inserted at position 1).

// ```
// {id: A, event: Insert('A', 0)}
// {id: C, event: Insert('C', 1)}
// {id: B, event: Insert('B', 1)}
// {id: D, event: Insert('D', 2)}
// ```




== Prepare and CRDT Versions <prepareversion>

Before running _prepare_, eg-walker calls a special _setPrepareVersion_ method. This method modifies eg-walker's internal state to ensure that the resulting CRDT message produced by _prepare_ is independent of any other concurrent events which have been visited.

Lets unpack that.

First, note that every CRDT state always has an associated _version_, defined by the set of all CRDT messages which have, so far, been merged in.

During traversal, eg-walker runs FugueMax's _prepare_ and _effect_ methods in sequence on each event to create CRDT messages and merge them in to the local state. _prepare_ takes a CRDT state as input, and inspects that state to compute the corresponding CRDT message.

However, in order to correctly convert the event into a CRDT message, the version of the CRDT passed to _prepare_ must exactly match the event's parent version. There are two reasons for this:

+ Each editing event's position is expressed relative to the document at that parent version.
+ The resulting CRDT event depends on the CRDT's state at the parent version. FugueMax's _prepare_ method converts events from the format listed above to either _insert(id, origin_left, origin_right, x)_ or _delete(id)_. Delete messages contain ID of the item being deleted, and insert messages need _origin-left_ and _origin-right_ fields to be filled in based on the ID of adjacent fugue tree items when the message was created.

As a result, during our traversal we cannot simply run FugueMax's _prepare_ function using a CRDT state constructed by merging all events visited so far.

We can see this problem in the example above. When converting event $C$ into the corresponding CRDT message, _prepare_ must function _as if_ the CRDT contained only event $A$ ($C$'s transitive parents). If _prepare_ runs using the CRDT generated by all visited events (both A and B), it would incorrectly generate the following CRDT message:

```
{id: C, originLeft: A, originRight: B, x: 'C'} // originRight is incorrect
```

Given this message, our local replica would incorrectly conclude that "C" must appear before "B" in the resulting document, and produce the incorrect result "ACDB". This behaviour would change depending on the traversal order chosen by the algorithm. // The order of concurrently inserted items "B" and "C" would depend on the traversal order rather than (correctly) tie-breaking based on a comparison of the event IDs.

//  eg-walker needs to run FugueMax's _prepare_ and _effect_ methods as if they happened at different points in time. _prepare_ must be run as if it happened at the version of the event. And _effect_ must run as if it happened at the resulting (merged) version.

// Normally, this isn't a problem as _prepare_ is only run on the peer which generated each change, when the event happened. At that moment in time, the local replica stores the CRDT state in memory at the parent version.

In order to solve this problem, eg-walker's state differs from FugueMax in one important way: Instead of representing the state at a single version (corresponding to the set of all witnessed events), eg-walker's state describes the corresponding FugueMax CRDT state at 2 different versions simultaneously:

- A _prepare version_ #vp, used by _prepare_ and
- An _effect version_ #ve, used by _effect_.

Eg-walker implements this by storing two separate state variables on each node in the tree: #sp and #se, which store the node's state at #vp and #ve respectively.

Immediately before running _prepare_, eg-walker modifies #vp (by adjusting #sp on the nodes in the tree) to match the event's parent version. The _prepare_ function generates its CRDT message from the FugueMax state described by #sp.

// #ve represents the set of all events visited so far in our traversal of the event graph. Thus #se mirrors the state of the equivalent FugueMax CRDT. (However in FugueMax, the state of each node this is represented by the item storing its original value $x$ or the tombstone value $perp$).

// However, before calling _prepare_ during event traversal, #vp

// #vp, on the other hand, can be adjusted at any time, to represent any arbitrary version containing a subset of the events represented by #ve.

// Immediately before calling _prepare_ during event traversal, #vp is set to the event's parent version using the _setPrepareVersion_ method defined in [Algorithm X]. The _prepare_ method uses the state as described by #vp to produce its CRDT message.


== Formalizing Eg-Walker's state

With all that theory out of the way, we will now more formally define eg-walker's state.

Eg-walker's state is a slightly modified version of FugueMax's state. The most important change from FugueMax is that each node in the tree stores an additional state variable #sp representing the node's state at some version #vp. This state is used by the _prepare_ function to generate the corresponding CRDT message. #sp is constantly updated throughout the traversal of the event graph.

Eg-walker's state consists of:

/ A tree of _nodes_: Each node in the tree stores the tuple of $("i", italic("leftOrigin"), italic("rightOrigin"), sp, se)$ as per FugueMax. Fields are defined below.
/ A _delete map_: mapping from the ID of each delete event to the ID of item which was deleted.

Each node in the tree corresponds to an item that has been inserted at some point in the set of events processed so far. The fields are:

/ $i$: is the ID of the node's corresponding insert event
/ _leftOrigin_ and _rightOrigin_: are the IDs of the items immediately to the left and right of $i$ when the node was created. See the Fugue paper for details @fugue.
// / _side_: is _L_ or _R_, marking the node as a left or right child. See the [fugue paper] for details.
/ #sp: is the state of the node at version #vp. $sp in { mono("NotInsertedYet"), mono("Ins"), mono("Del(1)"), mono("Del(2)"), ... }$.
/ #se: is the state of the node at version #ve. $se in { mono("Ins"), mono("Del") }$. In FugueMax, these two states correspond to the stored item either containing its original value $x$, or the value having being replaced with a tombstone $perp$, respectively.

// As well as the tree of nodes, for each visited delete event $i$, the algorithm also stores $t_i$: the ID of the item targeted by $i$.

// Eg-walker obeys FugueMax's ordering rule $lt.curly$. Items are ordered using the FugueMax algorithm.

// There are two small departures from FugueMax as written in the paper:

// + The value of each node is not actually stored in the tree. Because the content of inserted items is emitted directly during traversal, there is no need to store the value of each item in the tree itself. @transform contains a longer discussion of this approach.
// + We do not explicitly store FugueMax's _side_ parameter, as it is redundant.

// Before running _prepare_ on each event $i$, the algorithm first sets #vp to $P_i$, by adjusting #sp on all nodes in the tree to the state of the item at the events' parent version $V_i$.
Before running _prepare_ on each event $i$, the algorithm first sets #sp on all nodes in the tree to match the state of the item at the events' parent version $P_i$:

// The value of #sp always matches on the state of the inserted item at version #vp:

- If $i in.not ceil(P_i), sp := mono("NotInsertedYet")$
- If $i in ceil(P_i)$ but the item has not been deleted at $P_i$, $sp := mono("Ins")$
- If $i in ceil(P_i)$ and the item has been deleted at $P_i$, $sp := mono("Del")(n)$ where $n$ is the number of delete events in #vp targetting $i$. (Items can be deleted by multiple events if the delete events are mutually concurrent).

// Before _prepare_ processes each event $i$, #vp is set to the event's parents $P_i$. This is done by setting #sp to the correct value on all nodes in the state tree.

For efficiency, instead of traversing the entire tree of nodes before each event is visited, #sp is updated incrementally. As each event is visited, the set difference is computed between #vp (the version of the previously visited event) and $P_i$ (the parent version of the current event). The set difference returns a set of added events and a set of removed events. Each event added or removed from #vp modifies the state of the corresponding node in the state tree.

#sp is updated on the corresponding node as follows:

- If an insert event is added, #sp moves from `NotInsertedYet` to `Ins`
- If a delete event is added, #sp on the delete event's target moves from `Ins` to `Del(1)` or `Del(n)` to `Del(n+1)`.
- If an insert event is removed, #sp moves from `Ins` to `NotInsertedYet`
- If a delete event is removed, #sp on the delete event's target moves from `Del(1)` to `Ins` or `Del(n)` to `Del(n-1)`.

#figure(
  fletcher.diagram(
    // cell-size: 3mm,
    spacing: (4mm, 4mm),
    node-stroke: 0.5pt,
    node-inset: 5mm,
    // node-shape: "circle",
  {
    let (nyi, ins, del1, del2, deln) = ((0, 0), (1, 0), (2, 0), (3, 0), (4, 0))
    node(nyi, "NYI") //, shape: "circle")
    node(ins, "Ins", stroke: 1.1pt) //, shape: "circle")
    node(del1, "Del(1)") //, shape: "circle")
    node(del2, "Del(2)") //, shape: "circle")
    node(deln, $dots.c$, shape: "rect") //, shape: "circle")

    edge(nyi, ins, bend: 50deg, label: [\+ Ins], "->")
    edge(ins, del1, bend: 50deg, label: [\+ Del], "->")
    edge(del1, del2, bend: 50deg, label: [\+ Del], "->")
    edge(del2, deln, bend: 50deg, label: [\+ Del], "-->")

    edge(ins, nyi, bend: 50deg, label: [\- Ins], "->")
    edge(del1, ins, bend: 50deg, label: [\- Del], "->")
    edge(del2, del1, bend: 50deg, label: [\- Del], "->")
    edge(deln, del2, bend: 50deg, label: [\- Del], "-->")

    // edge(start, a, "-")
    // edge(a, b, "-")
    // edge(b, d, "-")
    // edge(a, c, "-")
  }),
  caption: [State machine diagram for #sp]
) <spv-state>


// - At the start of the algorithm, store $vp = emptyset$. #vp stores the version at represented by #sp on all nodes in the tree.
// - _setPrepareVersion_ compares the incoming event's parent version $P_i$ with the previous version #vp. The difference between versions will usually show some added events and some removed events. #sp is only modified on the subset of nodes which have changed state between #vp and $P_i$.
// - $vp := P_i$, and used as the basis for com

// The set difference between two nearby versions can usually be computed very efficiently. In @optimisations we present an efficient set difference algorithm, and other helpful graph related tools. > TODO: ADD THE ALGORITHM AND REFERENCE IT DIRECTLY!

#claim[
  Eg-walker's state, as described by #sp on each node, exactly matches the FugueMax tree at #vp. Specifically, the FugueMax tree can be generated by projecting all nodes in eg-walker in the following way:

  - If $sp = mono("NotInsertedYet")$, the item and its subtree is elided. (All children of such elements will also have $sp = mono("NotInsertedYet")$).
  - $sp = mono("Ins")$ corresponds to a FugueMax item with its original value $x$
  - $sp = mono("Del")(d)$ corresponds to a FugueMax item with a tombstone value $perp$.

  PROVE ME!
]

The _prepare_ method runs on this projection of the state tree to generate the corresponding CRDT messages:

- Delete messages target the $i$-th item in the tree's traversal with $sp = mono("Ins")$.
- Insert messages set the following properties:
  / originLeft: The ID of the $(i - 1)$-th node with $sp = mono("Ins")$, or `Start` if $i = 0$
  / originRight: The ID of the next node after _originLeft_ where $sp != mono("NotInsertedYet")$, or `End` if no subsequent node exists.

#claim[
  The _prepare_ function, called after setting #vp = $P_i$, produces identical CRDT messages as FugueMax in all cases.

  PROVE ME!
]


// The logic to update #sp differentially is given by the following algorithm.

// ```
// // State is implemented with an integer:
// enum State {
//    NotYetInserted = -1,
//    Ins = 0,
//    Del(n) = n
// }messages
//     }
//     state.nodes[id].sp += 1
//   }

//   state.vp := parentVersion
// }
// ```

When the _effect_ method merges messages into eg-walker's state, the event is added to #vp. #sp and #se are set accordingly based on the event:

- Insert messages insert a new node into to the state tree corresponding to the inserted content. The new node is positioned in the tree according to FugueMax. The node has $sp = se := mono("Ins")$.
- Delete messages set $se := mono("Del")$ and $sp = mono("Del(n)")$ on the deleted node. #sp is modified using the same logic as _setPrepareVersion_, described above. Delete messages also update the state's _delete map_.

// The event may also be added #vp (setting #sp on the modified node). However, because _setPrepareVersion_ is always called before _prepare_, this choice has no bearing on the algorithm's behaviour.

#claim[
  After the _effect_ method runs, eg-walker's state exactly matches the corresponding FugueMax tree at #ve, where #se represents whether the item contains its original value $x$ or a tombstone $perp$.
]

The eg-walker state thus simultaneously represents the equivalent FugueMax's tree at two versions: #vp and #ve, with $ceil(vp) subset.eq ceil(ve)$ at all times.

Because the CRDT messages and effect logic always match FugueMax, the resulting document order will also always match the order produced by FugueMax.

#claim[
  The document state produced by $r(G)$ is independent of the traversal order. This follows from FugueMax's commutativity property.
]


= Partial Traversal <eg-partial>

The algorithm given above will accurately replay any event graph of sequence events to generate the corresponding fugue CRDT - and resulting document state. However, this algorithm still has a big drawback: It visits every event in the event graph in the process. This is slow for large documents, memory inefficient and it requires the entire event graph be made available at all times to all replicas. (Ie, we can't prune the graph).

In this section we present a some optimisations to eg-walker to allow for partial traversal. Partial traversal allows a document snapshot at some version $V_0$ to be updated to incorporate all the events in version $V_m$ (the merged version), without traversing the entire event graph in the process.

== Naive Partial traversal

> TODO: Consider deleting this!

Consider a peer with a local document state $d$ at version $V_0$, such that $d = r(ceil(V_0))$. The peer wishes to merge all events at version $V_m$ - perhaps from another peer - into the local document state such that we can produce $r(ceil(V_0 union V_m))$.

We want the list of transformed operations $[e_1, e_2, ..]$ such that:

$ d plus.circle [e_1, e_2, ..] = r(ceil(V_0 union V_m)) $

// We need an algorithm which can produce this list of transformed operations. //which may be applied to a document at $V_0$ to generate the document at version $floor(V_0 union V_m)$.

We can implement this quite simply by modifying the traversal order in the algorithm presented above:

+ First all events in $ceil(V_0)$ are traversed, using the algorithm above. Transformed operations produced in this phase are discarded.
+ The traversal continues with the set of new events added in $V_m$, namely $ceil(V_0 union V_m) - ceil(V_m)$. Transformed operations generated in this phase are emitted.

The two phases essentially generate two sequences of transformed events:

- Phase 1 generates a sequence of operations $A = [a_1, a_2, ..]$ such that $d_0 plus.circle A = r(ceil(V_0))$.
- Phase 2 generates a sequence of operations $B = [b_1, b_2, ..]$ such that $d_0 plus.circle A plus.circle B = r(ceil(V_0 union V_m))$.

Substituting $d = r(ceil(V_0))$ yields $d plus.circle B = r(ceil(V_0 union V_m))$. So the vector of operations $B$ will transform $d$ to $r(ceil(V_0 union V_m))$, as desired.

// Because the resulting document state is independent of the traversal order, and the current document state $d = r(ceil(V_0))$

Unfortunately, this algorithm will run very slowly in practice:

- It will be called every time a node receives an event from a remote peer
- This algorithm visits every node in the graph every time it is called

We could solve these problems by caching the eg-walker state. However, this would undermine many of the advantages of using the event graph directly, as the cached state would need to be available at all times on all peers.

== Optimised Partial Traversal <opt-traversal>

Fortunately, the partial transform function can be massively optimised by taking advantage of a surprising property of eg-walker:

#claim[
  In order to correctly transform a visited event, the state tree *only* needs to represent information about other concurrent events which have already been visited.

  // Specifically, while visiting event $i$, the tree only needs to model visited events $j_1, j_2, ..$ which are concurrent with $i$.

  Formally, when visiting event $i in G$, the state tree only needs to store information about other visited events $j in ve$ where $j || i$.

  There are 2 kinds of information the state tree stores about event $j$: the resulting state $se$ of the node modified by $j$, and if $j$ represents an insert, the _id_, _originLeft_ and _originRight_ fields in node $j$.

  This information is needed for 2 purposes:

  + The transformed position of event $i$ only changes as a result of nodes in the state tree where $sp != se$. The only nodes with $sp != se$ are nodes representing either:
    - A concurrently inserted item, with ID $j$. In this case, visiting $i$, $sp = mono("NotInsertedYet")$ and $se in { mono("Ins"), mono("Del") }$.
    - The target of a concurrent delete event. In this case, when visiting $i$, it may be the case that $sp = mono("Ins")$ and $se = mono("Del(n)")$ for some $n$.
  + The algorithm must order inserted items correctly using FugueMax. If concurrent insert events $i$ and $j$ target the same final location in the document, when processing $i$, FugueMax's _effect_ function may compare the _id_, _originLeft_ and _originRight_ fields in node $j$ to decide the relative order of items $i$ and $j$.
] <opt-traversal-claim>

This property makes intuitive sense, as the position of each event already takes into account all causally earlier versions in the event graph. However, it is remarkable that this property is evident in the algorithm

We can use this property to allow eg-walker to make several clever optimisations which result in much better performance in many cases.

These optimisations are not available to CRDTs because CRDT based collaborative editing systems typically do not track the version of remote peers. As such, they do not know ahead of time what data the state tree needs to represent.

=== Justifying @opt-traversal-claim

// @opt-traversal-claim is

On careful inspection of the algorithm, data in the tree is only relevant in 3 cases:

+ CRDT messages use node IDs to pass position information from the _prepare_ to the _effect_ function. For example, a `Delete(pos: 12)` event becomes CRDT message `Delete(id: X)`.
+ In order for _prepare_ to correctly interpret the position of an event, #sp in each node needs to be set to the state at the parent version of the visited event.
+ Concurrent inserts at the same final location in the document must be ordered using FugueMax's ordering rules. FugueMax uses _id_, _originLeft_ and _originRight_ to decide on the resulting order of items.

In each of these 3 cases, when visiting node $i$, the reduced state tree (containing only information about events concurrent with $i$) will still result in the same transformed output after processing event $i$.

In *case 1*, passing position information from _prepare_ to _effect_ only requires that every node in the tree has a locally unique ID. The same IDs identified in _prepare_ are immediately used by _effect_. The exact bit strings representing those IDs doesn't matter. Our optimised state tree (containing a combination of "dummy nodes" and real nodes) still meets this criteria as dummy nodes are given locally unique IDs too.

For *case 2*, the algorithm needs to be able to set #sp to the parent version of each event we visit during the traversal. Due to the simplification, the algorithm would misbehave if it ever attempted to:
// Any item inserted before $C$ will not have its correct ID, and any item deleted at $C$ will not be present in the state tree at all.

- "Un-insert" any dummy items. Ie, we cannot set #sp to `NotInsertedYet` for any events inserted before $C$. This would fail because the dummy item's ID does not match the corresponding event ID.
- "Un-delete" any events which were deleted at version $C$. We cannot set #sp to `Ins` for any items which were deleted at $C$ because there is no node present in the state tree corresponding to these items.

Both of these errors would occur in the same situation. The algorithm will misbehave if the traversal ever visits an event with parent version $P$, where $C$ did not _happen-before_ $P$. However, this will never occur by construction, because:
- $C$ is a critical version and
// - $C -> {V_0, V_m}$
- The traversal only visits events which happened after $C$.

Note, dummy nodes can still be deleted and "un-deleted". This functions correctly as expected.

For *case 3*, we consider cases where the final insertion order of two inserts $i_1$ and $i_2$ depends on FugueMax's ordering rules, using _id_, _originLeft_ and _originRight_ to break "ties".

For FugueMax's ordering rules to have any bearing on the resulting insertion order, $i_1$ and $i_2$ must:
- Be concurrent
- Insert their content into the same location in the document.

For the FugueMax ordering rules to order insert events $i_1$ and $i_2$ correctly, both nodes must be visited during the traversal. This will result in _id_, _originLeft_ and _originRight_ being populated normally.

Traversing from version $C$ guarantees that this happens in all cases.

Because $C$ is a critical version and the events are concurrent ($i_1 || i_2$), it follows that either $C -> {i_1, i_2}$ or ${i_1, i_2} -> C$.

If $C -> {i_1, i_2}$, both nodes will be visited normally during the traversal of events. _id_, _originLeft_ and _originRight_ fields are populated and compared correctly using FugueMax's ordering rules. _originLeft_ and _originRight_ may point to dummy nodes, but that has no impact on FugueMax's ordering algorithm.

On the other hand, if ${i_1, i_2} -> C$, the relative ordering of $i_1$ and $i_2$ is irrelevant, as the inserted items are already present in both $V_0$ and $V_m$. (This follows from the definition of greatest common version - as $C = V_0 sect.sq V_m$ implies $C -> {V_0, V_m}$).


=== Starting at the greatest common version

The simplest way to take advantage of this property is to change where we begin our traversal. Instead of starting at the root version $emptyset$, the algorithm can start at the _greatest common version_ of $V_0$ and $V_m$ - which is the last _critical version_ which is equal to or before - both versions $V_0$ and $V_m$.

// Intuitively, critical versions form a sort of "firebreak" for ordering information. In FugueMax (and many other sequence CRDT algorithms), it is impossible for the order of items inserted _before_ any critical version to impact the order of items inserted _after_ a critical version.

More formally:

#definition("Greatest Common Version")[
  Consider 2 versions $V_1$, $V_2$, and the event graph $G$ containing all events in either version: $G = ceil(V_1) union ceil(V_2)$.

  We define the _greatest common version_ $C = V_1 sect.sq.double V_2$ on $G$ such that:

  - $C$ contains a subset of the events in $V_1$ and $V_2$. Ie, $C -> V_1 and C -> V_2$. // $forall i in C: i in ceil(V_1) and i in ceil(V_2)$
  - $C$ is a critical version (defined in @critical-version)
  - $C$ is the "most recent" version meeting the aforementioned criteria.

  The greatest common version is well defined for any two versions because:

  - The root version $emptyset$ is a critical version in every event graph
  - All of the critical versions in a graph are fully ordered.
]

Algorithmically, given we want to merge versions $V_0$ and $V_m$, we can optimise the partial transform algorithm by:

1. Computing $C = V_0 sect.sq.double V_m$
2. Traversing from C to $V_0$, discarding transformed operations along the way
3. Traversing from $V_0$ to $V_m$ as described in @eg-partial above.

This approach skips all events before (or in) $C$ - which will often contain most of the events in the event graph.

The algorithm can no longer start with an empty state tree, because items present in the document at version $C$ still need to be marked as deleted. Instead, the state tree is initialised with a set of "dummy nodes". Each node corresponds to an item that was present in the document at version $C$. Dummy nodes have arbitrary, locally unique IDs and $sp = se = "Ins"$ corresponding to initial $vp = ve = C$.

The state tree needs to be initialised with at least as many dummy nodes are there were items in the document at version $C$. Unfortunately the number of items in the document at $C$ is usually unknown. But this can be worked around by adding dummy nodes lazily during the _effect_ function, or if the internal run-length encoding optimisation is in use, a single RLE node can contain a functionally infinite list of dummy nodes.

#figure(
  fletcher.diagram(
    cell-size: 0mm,
    spacing: (2mm, 2mm),

    // debug: 2,
  {
    let (start, a, b, c, d) = ((0,0), (1,-1), (2, -2), (3, -3), (4, -4))
    node(start, [_start_], shape: "circle")
    node(a, $d^1$)
    node(b, $d^2$)
    node(c, $d^3$)
    node(d, $dots.down$)
    edge(start, a, "-")
    edge(a, b, "-")
    edge(b, c, "-")
    edge(c, d, "-")
  }),
  caption: [Left-origin FugueMax tree with dummy nodes $d^1, d^2, d^3, dots$]
)

// - Dummy IDs $d_0$, $d_1$, $d_2$, etc
// - $sp = se = "Ins"$
// - _originLeft_ of _Start_, $d_0$, $d_1$, etc
// - _originRight_ $=$ _End_


The optimised partial traversal algorithm is given in [Algorithm X].

// The algorithm above [XX] is a special case of this algorithm, with $V_0 = emptyset$ and $V_m = floor(G)$.

```
function transformPartial(graph, v0, vm) -> Iterator<TransformedOperation> {
  state := new EgWalkerState()
  state.addDummyNodes({
    id in ["dummy 0", "dummy 1", "dummy 2", ..]
    originLeft in [(start), "dummy 0", "dummy 1", ..]
    originRight = (end) for all nodes
  })

  cv := graph.greatestCommonVersion(v0, vm)

  for event (i, e, p) in graph.inOrderTraversalBetween(cv, v0) {
    state.setPrepareVersion(p)
    message := state.prepare(i, e)
    state.effect(message) // Transformed event is discarded.
  }

  for event (i, e, p) in graph.inOrderTraversalBetween(v0, v0 + vm) {
    state.setPrepareVersion(p)
    message := state.prepare(i, e)
    transformedOperation := state.effect(message)

    yield(transformedOperation)
  }
}
``` <eg-walker-algorithm>

// In practice, the greatest common version $C$ is usually either equal to $V_0$, or very close to $V_0$ in the graph. As a result, this change massively improves performance of the algorithm.

This optimised algorithm produces the same transformed list of operations as the naive algorithm described above. But it relaxes many of the FugueMax correspondence claims:

- The state tree no longer corresponds exactly to the equivalent FugueMax tree at #vp and #ve.
- CRDT messages generated by _prepare_ will not match their equivalents in FugueMax:
  - Insert events may name the ID of dummy nodes in their _originLeft_ and _originRight_ fields.
  - When a delete event targets an item which was inserted before version $C$, the corresponding delete message will specify the ID of the corresponding dummy node.

// Remarkably, this optimisation has no effect on the output of the function. The reason is quite subtle. We justify this optimisation below, and we have also run billions of fuzz test iterations to verify this claim.


=== Clearing the state and null transformation

There are 2 more ways we can speed up the system using @opt-traversal-claim and critical versions.

During the traversal, the algorithm sometimes visit an event $i$ where the event's parent version $P_i$ is a critical version in the set visited events ($G = ceil(V_0 union V_m)$).

In this case, because of the nature of critical events, all subsequently visited events must be causally after $P_i$. Because causally later events are unaffected by the state object, all information stored in the eg-walker state can be discarded. We reset the state to a list of dummy nodes.

Also, any time the state does not contain any concurrent events, the transform function will have no effect on the event itself. The event already entirely describes its behaviour at its own parent version - so when the document is at the parent version, no transformation is needed. On its own, this fact wouldn't help much as we would still need to add the corresponding CRDT message to the eg-walker state. However, if both an event's version and its parent version are critical versions, the state doesn't matter (it will be cleared anyway). So the transform function can simply yield the original event data $e$ directly. We do not need to run the CRDT's _prepare_ or _effect_ functions at all.

// In a totally linear event graph, every event is a critical version. In this case, the transformPartial function returns the event graph itself in causal order. No data structure is built, and no additional memory is consumed to build it.
This happens a lot in practice. Many editing histories are completely sequential (for example, the editing trace fo this document). When the event graph is entirely sequential, the transform function simply returns a traversal of the event graph. No additional memory is consumed. Even when editing histories contain some concurrent edits, its very common to have large runs of sequential, critical events. We see this show up in the _node_nodecc_ editing trace later in this paper.

Taken together, we call these two optimisations _fast forwarding_.

// Further, if ${i}$ is also a critical version (ie, if $exists.not j in G: j || i$), the state does not need to be updated to include $i$, for the same reason as above. So we do not need to run the CRDT's _prepare_ or _effect_ functions at all.

The algorithm presented above can be modified as follows:

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

// ```
// function resetState(state: EgWalkerState) {
//   state.clear()
//   state.addDummyNodes(...) // as above
// }

// function transformPartial(graph, v0, vm) -> Iterator<TransformedOperation> {
//   state := new EgWalkerState()
//   state.clear()

//   cv := graph.greatestCommonVersion(v0, vm)

//   for event (i, e, p) in graph.inOrderTraversalBetween(cv, v0) { ... } // as above.

//   for event (i, e, p) in graph.inOrderTraversalBetween(v0, v0 + vm) {
//     if p.isCriticalVersion() {
//       state.clear()

//       if [i].isCriticalVersion() {
//         yield(e)
//         continue
//       }
//     }

//     state.setPrepareVersion(p)
//     message := state.prepare(i, e)
//     transformedOperation := state.effect(message)

//     yield(transformedOperation)
//   }
// }
// ```

// Completely linear event graphs are extremely common in practice, as many documents are only ever edited by a single user making sequential changes. In a totally linear event graph, every event is a critical version. In this case, the transformPartial function returns the event graph itself in causal order. No data structure is built, and no additional memory is consumed to build it.

// Even when users work on a document together, critical versions are still common. Constantly trimming the size of the working set makes a large practical difference in performance.

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


It may be possible to trim the state in an even more fine-grained way. However, we have not figured out how to do so in an efficient manner.


// First, recall that critical events cleanly partition the event graph into 2 groups of events: the events before (or equal) to the critical version, and all events causally after the critical version. Because the traversal is in causal order, we will have processed all events in  Due to @opt-traversal-claim,

/*
= Other Optimisations <optimisations>

We have written a highly optimised implementation of our eg-walker algorithm in rust, based on the logic listed above and using a lot of optimisation "tricks" to improve performance as much as possible. In the past, poor performance of CRDT based algorithms has hampered their adoption in industry, and given CRDTs a reputation for being impractical in real systems.

In this section, we briefly describe some other optimisations we have made which dramatically improve the performance of both CRDT based approaches and eg-walker. //Where possible, we also benchmark the performance gain from these optimisations in isolation. Though this is not always easy, and it is not indicative of the performance gain when multiple optimisations are applied together.

Many of the optimisations listed here can also be applied to CRDT based text editing systems. We have also written an highly optimised implementation of FugueMax as a regular CRDT, hereafter _fugue-crdt_. fugue-crdt shares as much code as possible with our optimised eg-walker implementation in order to make the comparison as fair as possible.

// We also include comparisons with contemporary CRDT based libraries like Yjs and Automerge.

// In this chapter, we will describe these optimisations and, where possible, benchmark their performance in isolation.

// Some optimisations can also be used to improve the performance of traditional CRDTs. All optimisations like this have also been applied in our fugue-crdt implementation.

In the benchmarking chapter [x] below, we will assess eg-walker against fugue-crdt and other contemporary CRDT implementations on a number of metrics, using a variety of real-world editing traces that we have recorded as part of this work.

Many of these optimisations are not novel. We suspect many of these tricks have been discovered many times by different engineering teams, but simply not written up. We will give attribution wherever we can, but apologise in advance for any omissions.


== Agent & Sequence number for event IDs

Each event or CRDT message needs an assigned globally unique ID. The most obvious approach is to assign every event a GUID using some UUID scheme, like RFC4122 [REFERENCE].

Unfortunately, this approach dramatically bloats file size. RFC4122 UUIDs are 16 bytes long and largely uncompressible. If a new UUID is assigned on every keystroke, filesize would be quickly dominated by storing the UUIDs for each event.

A better approach is to assign (agent, seq) tuples to events. The agent ID is assigned only once per editing session. Sequence numbers store autoincrementing integers. These compress extremely well due to the nature of how humans edit documents.

> STATS

One downside of this approach is that it makes systems vulnerable to byzantine actors on the network. [Martin - BFT] paper discusses using Git-style hashes instead, however as far as we know, doing this in a space-efficient way is still an unsolved problem.

This optimisation is present in both Automerge and Yjs. We do not know when it was first discovered. (TODO: ??? Can we find this reference?)


== Local IDs and Remote IDs

// Versions are quite large objects, containing a unique ID and a sequence number.

In our implementation, replicas associate each "remote ID" (the (agent, seq) tuple pairs mentioned above) with a _local ID_, which is simply an autoincrementing integer. The first event added to the local event graph is numbered 0, then 1, then 2 and so on.

Because events are added to the event graph in causal order, given two events with local IDs $i_1$ and $i_2$ where $i_1 < i_2$, we know event $i_2$ must have been added to the local event graph after event $i_1$. As such, it is impossible for $i_2$ to have _happened-before_ $i_1$. Thus $i_1 < i_2$ implies that either $i_1 -> i_2$ or $i_1 || i_2$.

// IDs are used everywhere throughout the library. Using simple integers yields a small but constant performance gain in these cases.

Surprisingly, this simple property simplifies and improves the performance most event graph queries. The event graph is queried constantly by eg-walker. For example:

- When the partial transform function is queried to merge $V_m$ into $V_0$, it first needs to compute the _greatest common version_ $C = V_0 sect.sq.double V_m$.
- During traversal, before visiting each event, eg-walker computes the set difference between #vp (the version of the previously visited event) and $P_i$ (the parent version of $i$). The set difference function returns sorted lists of added and removed events.
// - During traversal, the algorithm adds and removes events from #vp. Because versions are sets of IDs of an event graph's frontier, this

And many more.

Consider the `versionContainsLocalId` function, which computes whether $i in ceil(V)$ for some event (specified by local ID) and version. If $i$ is not in $ceil(V)$, a naive implementation of this function may need to expand and search all of $ceil(V)$. However, the local ID ordering property allows us to bound the search to only visit events $j in ceil(V)$ where $j >= i$. This algorithm is given in @example-localid-algorithm.

Many other event graph queries can be sped up this way, including set difference, set union and set intersection functions for versions. TODO SEE CAUSALGRAPH LIBRARY FOR MORE

// However, the local ID ordering property tells us that for any event $j in ceil(V)$ where $j < i$, it is impossible for $i -> j$. Therefore, we can bound the search to only visit events $j$ where $j >= i$. This algorithm is given in @example-localid-algorithm.



// Consider the _diff_ function, which computes the set difference between two versions. A naive diff function operating on two versions (represented by sets of IDs) may do a parallel breadth-first search to find the ways the versions differ. This is quite slow and it uses a lot of RAM. Even in the simple case where $V_1 -> V_2$ or $V_2 -> V_1$, both versions will be expanded unnecessarily.

// Using local IDs, the algorithm gets much simpler, as the graph can be iteratively expanded from the highest local ID in $V_1$ and $V_2$ until the difference is found. A diffing algorithm which takes advantage of this is listed in @example-localid-algorithm.

// We have developed a suite of utility functions which are optimised like this. SEE causal-graph LIBRARY TODO!

As the name suggests, local IDs are never transmitted between replicas, as different replicas will not share their mapping between local IDs and _(agent, seq)_ tuple pairs.


== Internal Run-length encoding <opt-rle>

It is a somewhat obvious point, but humans do not typically make seemingly random edits in a document. Almost all editing events in an event graph:

- Are located next to the preceeding event:
  - An insert at position 50 is usually followed by an insert at position 51, then 52, and so on.
  - A delete at position 50 is usually followed by deletes at positions 49 or 50 (indicating the use of the backspace or delete keys, respectively).
- Events almost always happen causally right after the previous event in the graph. Ie, if the graph contains events ${i, j}$, the parent version of $j$ is usually ${i}$.
- IDs are almost always in sequence. If the previous ID is _(A, 50)_, the next ID will almost always be _(A, 51)_ then _(A, 52)_ and so on.

This pattern persists into the generated state tree. If a node looks like this:

```
(local_id: 50, origin_left: X, origin_right: Y)
```

The subsequent nodes almost always looks like this:

```
(local_id: 51, origin_left: 50, origin_right: Y)
(local_id: 52, origin_left: 51, origin_right: Y)
(local_id: 53, origin_left: 52, origin_right: Y)
```

Throughout our system, whenever possible we store data in an internally run-length encoded forms. For example, the state tree items listed above are instead stored in a single node like this:

```
(local_id: 50..54, origin_left: X, origin_right: Y)
```

The above item implies the IDs are _[50, 51, 52, 53]_, originLeft for the run of items is _[X, 50, 51, 52]_, and originRight is _[Y, Y, Y, Y]_. The logic for how each field is compressed is hardcoded per-field based on common usage patterns.

Items are merged opportunistically, and they can be split again without losing information.

When iterating through events, the algorithm always processes run-length encoded chunks of events at a time.

The event graph itself is stored in a struct-of-arrays form rather than an array-of-structs form. Ie, instead of storing the graph as an array of _(id, parents, position, insert_content?)_ objects, we store it in a set of arrays, with each array holding part of the data for each event. We use the following arrays:

/ Agent assignment: Stores the associations between local ID and remote ID
/ Graph: Stores the parents fields for each event.
/ Events: Stores each events' type (`Insert` or `Delete`) and position
/ Inserted content: A big string storing the inserted content

The agent assignment, graph and events arrays are all individually run-length encoded to reduce storage size. Separating these fields allows the "split points" to be different in each array. Local IDs are used to index everything, usually via a binary search.

This approach is based on Martin Kleppmann's work optimising file sizes for CRDTs. [REFERENCE??]

> STATS ON IMPACT


== Tree -> List transformation <fugue-list>

In its paper, FugueMax is defined in terms of a tree of items. Instead of storing the items in a tree, we use a variant of of FugueMax which instead places all items in a flat list. When new items are inserted, the system performs a linear scan across the range of possible insertion locations to decide where the newly inserted item should be placed. This scan is akin to an insertion sort.

Using a flat list is better for performance because the generated Fugue tree is extremely unbalanced. Scanning to find items in the fugue tree is closest to scanning a linked list. It has terrible performance in modern computers due to cache thrashing.

The insertion sort formulation also requires much less code. In Typescript, Weidner's "simple" implementation of FugueMax requires 594 lines of code [LINK TO fugue-simple]. In comparison, the list formulation of the same algorithm needs less than 100 lines. The core insertion function is about 40 lines long, and is included below in @list-fuguemax-code.

// Linear scanning sounds slow, but in practice it only happens when concurrent items are inserted at the same location in the final document. This is very rare.

The _side_ field ($in {"L", "R"}$) specified in the Fugue paper is also not needed in this formulation of the algorithm.

As far as we are aware, this approach was first pioneered in the Yjs CRDT library by Kevin Jahns [REFERENCE]. This list based insertion approach was adapted by Joseph Gentle in [REFERENCE-CRDTs] to work with the RGA [REFERENCE] and Sync9 [REFERENCE] CRDTs. And Joseph Gentle created the novel "YjsMod" CRDT in the process, based on some changes made to Yjs. This approach is described in the [CRDTS GO BRRR] blog post.

We believe Sync9 is equivalent to Fugue and YjsMod is equivalent to FugueMax, and fuzzing results back this up. However, this claim has not been proven.

A preprint of the Fugue paper included a proof of equivalence between the tree and list formulations of Fugue. However, this proof has been removed from the final version to shorten the paper before publication.


== Range tree for CRDT structure - store the list as a tree again

The internal state needs to efficiently support the following operations:

- Look up a numeric document position (in #vp) to find the ID of the CRDT items at that location. This is used by _prepare_.
- Look up the ID of a CRDT item and modify the tree at that location:
  - When processing an insert event, the _effect_ function inserts new items at this location, and needs to return the transformed document position at version #ve, based on the current state #se of all items in the list.
  - Both the _effect_ and _setPrepareVersion_ functions need to modify the state of an item based on its ID.

We have made an efficient, somewhat exotic data structure which can perform any of these events in $O(log n)$ time, where $n$ is the number of items currently in the data structure.

The data structure works using 2 modified b-trees: a _core tree_ and _marker tree_.

The *core b-tree* stores all run-length encoded items in document order.

- Leaf nodes store a list of items. Each item has our two state variables #sp and #se, representing the state at #vp and #ve respectively.
- Internal nodes in the tree store two length variables, representing the length of all children at version #vp and #ve, based on the child state at #sp and #se respectively. The length is the recursive sum of the length of all children where the associated state variable is `Ins`.

The core b-tree can efficiently lookup any item in $log n$ time given a position at #vp by traversing down the tree. And any item's position at version #ve can also be calculated in $log n$ time by traversing back up the tree and aggregating the size of all previous items.

This data structure is based on Piece Trees, described in @vscode-buffer. They are also described in more detail in [CRDTS GO BRRR].

For each ID in the tree, the *marker tree* stores a pointer to the corresponding leaf node in the core b-tree. A lot of care is taken to update this data structure correctly whenever core b-tree nodes are split or joined.

> DIAGRAM HERE

The marker tree allows lookups into the tree by ID, which is used by both _effect_ and _setPrepareVersion_.

Both b-trees internally run-length encode all items. This, unfortunately, makes the code very complex. Including tests, our b-tree implementation is nearly 3000 lines of code.

Our pure CRDT based implementation _fugue-crdt_ uses the same data structure implementation, but each node only has a single state variable #se and associated length.

// Both of these lookups can be performed efficiently by


== Query plan (traversal order) optimisation

When traversing complex causal graphs, the performance of eg-walker depends a great deal on chosen traversal order.

The reason is that a great deal of time is spent in the _setPrepareVersion_ function, modifying the state of previously visited events. An ideal traversal order visits events in an order which minimises the number of nodes which need to have their state #sp modified by _setPrepareVersion_. Optimising traversal order appears to be a variant of the travelling salesman problem.

After a lot of experimentation, our current implementation traverses the event graph as follows:

First, each event in the graph is assigned an estimated cost. The cost is the total distance (measured in the number of events) between that event and to the final merged version. Ie, the cost of event $i$ when merging $V_0$ and $V_m$ is $Sigma (ceil(V_0 union V_m) - ceil({i}))$.

The event graph is then traversed in a depth-first search from the initial version $C$. Events with multiple parents are visited after their last parent is visited. When an event has multiple children, the children are visited from the child with lowest estimated cost to highest estimated cost.

Calculating this traversal order takes a significant amount of time for very complex event graphs.

> TODO: DATA SHOWING WHY THIS HELPS

*/

= Evaluation <benchmarking>

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

Eg-walker performance is much more varied than that of a CRDT. The reason is that the performance of a CRDT's _effect_ function is largely insensitive to the data. Eg-walker, on the other hand, is much faster than CRDTs when the event graph is largely sequential (or mostly sequential, as is the case in `node_nodecc`). This is due to the optimisations described in @opt-traversal. When part of an editing trace is sequential, the transform function resembles the identity function.

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

// We can define the length of each event at both #vp and #ve:

// $ op("len")_italic("in") := cases(
//   1 "if" sp = mono("Ins"),
//   0 "else"
// ) $

// $ op("len")_italic("out") := cases(
//   1 "if" italic("value") != perp,
//   0 "if" italic("value") = perp,
// ) $

// For each event $(i, e_i, P_i)$, eg-walker does the following steps:

// + Move #vp to the event's parent version $P_i$. After this step, $vp = P_i$
// + Apply $e_i$ to the internal state, running FugueMax's _prepare_ and _effect_ methods in sequence on the event. _prepare_ runs at #vp (using #sp defined below).
// + #vp and #ve are both modified to include $i$. ($vp' = vp union {i}$, $ve' = ve union {i}$)

// When the event is applied, the event's transformed position (at #ve) can be emitted in order to implement _transform_.


/*

== Document and CRDT versions

Recall that events are defined in the context of the edited document's _version_. For example, at the precise moment when this paragraph was typed, its starting character was at position 15343 in the document. By the time you're reading it, this paragraph will almost certainly have moved to a different position in the document, and position 15343 will point somewhere else. Position 15343, named by an delete or insert event, is only meaningful in relation to the document version in which the event happened.

The _prepare_ function in fugue (and similar CRDTs) converts local editing positions (position 15343 in our case) into a globally understandable identifier. The identifier keeps its _relative_ document position even in the presence of other concurrent changes which have been merged into the document. Fugue implements this by assigning every inserted character a unique ID. The start and end of the document use placeholder IDs.

/ Delete positions: are replaced by the ID of the deleted item
/ Insert positions: are replaced with a (_leftOrigin_, _rightOrigin_) ID pair. These are the IDs of the items immediately to the left and right of the newly inserted content at the moment that insert happens.

(This approach was pioneered by YATA and Yjs[ref]).

Fugue implements this translation by maintaining a tree of inserted items. When an insert happens, it does a lookup in the tree to find the ID of the surrounding items. It may seem like an obvious point - but this tree also changes over time as new CRDT events are merged in to the document. Just like the document, we can consider the CRDT state to have a version corresponding to the set of CRDT events which have been merged in via _effect_.

For _prepare_ to function correctly, the CRDT state version must exactly match the event's parent version. CRDTs normally find this property very simple to achieve because _prepare_ only runs on the replica which generated the event, usually synchronously within the editor's process.

However, in a replayable event graph based system, _prepare_ must be run on all replicating peers. For correctness, we also require that all peers translate the same event into the same (_leftOrigin_, _rightOrigin_) pair as FugueMax would have done. We need to do this even if the local state currently exists at a different version than the event's parents.

== Eg-walker Versions

Recall that a version is defined by the set $G$ of known events at some point in time. Fugue's state always exists at some version in time, corresponding to the set of events which have been applied.

// In order for _prepare_ to correctly convert events (at some absolute offset) into their

Its helpful to model this with 2 versions:

/ Event's parent version: The version of the document immediately before the event took place
/ CRDT version: The version of the local CRDT's state. This version is defined by the set of all events observed (directly or indirectly) by the replica.

_prepare_ has an implicit precondition that these two versions match. CRDTs achieve this by

Do you see the problem?

In order for eg-walker to correctly run FugueMax's _prepare_ function on each event in the event graph, it needs to correctly translate the event's position (specified in absolute terms - eg 15343) into the corresponding _leftOrigin_ and _rightOrigin_ ID pair, at the event's parent version.

To achieve this, eg-walker  associates an additional state variable to each item in the FugueMax tree.


// The _effect_ function also emits

// To do this,

// The document (the actual text) and the local replica's CRDT each exist at some version through time. When an edit happens, the events' parent version is the document's version right before the event happened. The _prepare_ function requires that the events' parent version exactly matches the CRDT's version.

In order for _prepare_ to work correctly, when a local edit happens the local replica's CRDT state's version must match the

CRDTs like Fugue rely on the document that the user is editing to match the CRDT's state on the local replica. The local replica converts the local position (15343) into some globally usable position identifier. In FugueMax's case, every insert's position is converted into a _leftOrigin_ and _rightOrigin_ ID pair.

 This Imagine a user inserting a character in a text document at position 100. Position 100 only makes sense relative to other surrounding characters in the document, visible at that time in the user's editor.

CRDTs like Fugue always exist at some (usually implicit) _version_. This version is defined by the set of all events observed (directly or indirectly) in the replica's state.

The _prepare_ function in CRDTs like Fugue depend on the events' parent version matching the CRDT's version.


// This version is often implied but not modelled explicitly.

The CRDT's prepare-update (generator) function requires that the CRDT's version exactly matches the document's version immediately before the event took place.

When a CRDT

The prepare-update (generator) function in the definition of a CRDT requires that the version of the document that the event was generated on event's version matches the version of the CRDT.


As we traverse the graph, events are processed through FugueMax's _prepare_ function and added to an internal data structure resembling FugueMax, constructed of items which look like this:

```
[
  {id: X, originLeft: _, originRight: _, inputState: S, outputState: S}
  {id: Y, originLeft: _, originRight: _, inputState: S, outputState: S}
  {id: Z, originLeft: _, originRight: _, inputState: S, outputState: S}
]
```

OriginLeft and originRight are defined according to the FugueMax algorithm.

As you can see, each item in the FugueMax list is augmented with two state variables, specifying the state at two versions: an input version $V_0$ and output version $V_1$. The input state is from the set of { `NotInsertedYet`, `Inserted`, `Deleted(1)`, `Deleted(2)`, `Deleted(3)`, ... } and the output state is simply either `Inserted` or `Deleted`.

// The list of items exactly correlates with the equivalent fuguemax tree. Items are listed in the same order, and have identical originLeft and originRight fields.

We can move the input version by changing the input state of stored items.

The data structure marries a CRDT style _prepare_ function at $V_i$ with an _effect_ style operation at $V_o$, which also outputs the transformed version of the event.

The output version $V_o$ moves monotonically forward as events are processed. The output version always corresponds to the version containing all processed events.

But we can move $V_i$ to any version, so long as $V_i = V_o or V_i -> V_o$

The traversal is conceptually simple. It works as follows:

```
for (id, event, parents) in graph.inOrderTraversal() {
  setPrepareVersion(parents)
  add(event)
}

fn setPrepareVersion(oldInputVersion, newInputVersion) {
  let {eventsRemoved, eventsAdded} = graph.diff(oldInputVersion, newInputVersion)
  for e in eventsRemoved.reverse() { // Iterate in reverse order
    disable(e)
  }

  for e in eventsAdded {
    enable(e)
  }
}
```

== Using a list for a list CRDT


*/

#show bibliography: set text(8pt)
#bibliography(("works.yml", "works.bib"),
  title: "References",
  style: "association-for-computing-machinery"
)

#counter(heading).update(0)
#set heading(numbering: "A", supplement: "Appendix")

= Generic CRDT to replay algorithm <generic-crdt-replay>

In this section, we present a generic replay function which matches the behaviour of any CRDT. See @crdt-equivalence for details.

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
