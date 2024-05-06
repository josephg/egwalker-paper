#import "@preview/cetz:0.1.2"
#import "charts.typ"


#set text(font: "FreeSans", size: 9pt)


=== ff_chart
#charts.ff_chart
=== speed_merge
#charts.speed_merge
#charts.speed_load
=== speed_ff
#charts.speed_ff


#figure(
  image("diagrams/test.svg", width: 50%),
  // text(8pt, charts.speed_ff),
  caption: [
    Time taken for alg to replay an event graph, with and without the optimisations from xxx.
  ],
  kind: image,
  placement: top,
) <speed-ff>



// === all_speed_remote:
// #charts.all_speed_remote

// === all_speed_local:
// #charts.all_speed_local

// === one_local
// #charts.one_local

=== Memory usage
#charts.memusage_all
#charts.memusage_steady
#charts.memusage_peak

#pagebreak()
== filesize_full

==== Option 1:
#charts.filesize_full

==== Option 2:
#charts.filesize_full2

== filesize_smol
#charts.filesize_smol







#bibliography(("works.yml", "works.bib"),
  title: "References",
  style: "association-for-computing-machinery"
)