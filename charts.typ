// This file contains charts for reg-text.typ. Its awkward including them inline, so I've moved
// them here.

// #import "@local/cetz:0.2.0": canvas, plot, draw, chart, palette, styles
#import "@preview/cetz:0.2.0": canvas, plot, draw, chart, palette, styles

#let datasets = (
  "S1", "S2", "S3", "C1", "C2", "A1", "A2"
)

#let algorithms = (
  "dt",
  "ot",
  "dtcrdt",
  "yjs",
  "automerge"
)

#let algnames = (
  dt: "Eg-walker",
  ot: "OT",
  dtcrdt: "Reference CRDT",
  yjs: "Yjs",
  automerge: "Automerge"
)

#let algcolors = (
  dt: rgb("#4269d0"),
  // dt: maroon,
  dtcrdt: red.desaturate(60%),
  yjs: rgb("#ff725c"),
  // yjs: aqua,
  automerge: rgb("#efb118"),
  // cola: fuchsia,
  // cola-nocursor: fuchsia.desaturate(70%),
  // jsonjoy: olive,
  ot: fuchsia,
)

#let dscolors = (
  S1: rgb("#1b9e77"),
  S2: rgb("#1b9e77"),
  S3: rgb("#1b9e77"),
  C1: rgb("#d95f02"),
  C2: rgb("#d95f02"),
  A1: rgb("#7570b3"),
  A2: rgb("#7570b3"),
)

#let p1_ff = json("results/xf-node_nodecc-ff.json")
#let p1_noff = json("results/xf-node_nodecc-noff.json")

#let xf_clown_ff = json("results/xf-clownschool-ff.json")
#let xf_clown_noff = json("results/xf-clownschool-noff.json")

#let p3_ff = json("results/xf-friendsforever-ff.json")
#let p3_noff = json("results/xf-friendsforever-noff.json")

#let scale_data(filename, sf) = {
  json(filename).map(val => (float(val.at(0))*sf, val.at(1)))
}

#let ff_chart = canvas(length: 1cm, {
  draw.set-style(
    legend: (
      default-position: "legend.inner-north-west"
    )
  )
  plot.plot(
    size: (6, 3),
    x-tick-step: 5,
    y-tick-step: 500,
    x-label: "Events processed (in thousands)",
    y-label: [Eg-walker state size],
    {
      plot.add(scale_data("results/xf-friendsforever-noff.json", 0.001), label: [without clearing])
      plot.add(scale_data("results/xf-friendsforever-ff.json", 0.001), label: [with clearing])
    }
  )
})



// // *** SPEEEED

// #let raw_timings = json("results/timings.json")

// #figure(
//   image("diagrams/test.svg", width: 80%, fit: "contain")
// )

#let bar_style(idx) = {
  (
    stroke: 0.1pt + black,
    // stroke: none,
    // fill: (red, green, blue, yellow, purple).at(idx),

    // fill: (palette.tango-colors, palette.light-green).at(idx),
    fill: palette.rainbow-colors.at(idx),
  )
}

#let barchart_style = (
  grid: (
    // fill: blue,
    stroke: (paint: luma(66.67%), dash: "dotted", thickness: 1pt)
  ),
  legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-south-east",
    item: ( preview: (width: 0.4) ),
    // stroke: none,
    stroke: (thickness: 0.3pt),
    padding: 0.1,
  ),

  bar-width: 0.8,
  y-inset: 0.7,
  axes: (
    // top: (stroke: (thickness: 0))
    bottom: (
      grid: (stroke: (dash: "solid", thickness: 0.3pt)),
      stroke: (thickness: 10pt),
    ),
    // left: (thickness: 0),
    stroke: (thickness: 0.4pt),
  )
)

#let timings = json("results/timings.json")
#let merge_times = (
  // "dt", "ot", "dtcrdt", "yjs", "automerge"
  dt: timings.dt_merge_norm,
  ot: timings.ot,
  dtcrdt: timings.at("dt-crdt_process_remote_edits"),
  yjs: timings.yjs_remote,
  automerge: timings.automerge_remote,
)
#let load_times = (
  dt: timings.dt_opt_load,
  ot: timings.dt_opt_load,
  dtcrdt: merge_times.dtcrdt,
  yjs: merge_times.yjs,
  automerge: merge_times.automerge,
)

#let am(items) = {
  let sum = items.sum()
  return sum / items.len()
}
#let gm(items) = {
  let prod = items.product()
  return calc.root(prod, items.len())
}

#let map_dict(d, f) = {
  let result = (:)
  for (key, val) in d.pairs() {
    result.insert(key, f(val))
  }
  return result
}

#let avg_opt_load_time = am(timings.dt_opt_load.values())

// #let xxx = map_dict(("hi": 3), x => x + 1)

// #let x = algorithms.map(alg => gm(merge_times.at(alg).values()))
// #let x = map_dict(merge_times, t => gm(t.values()))
#let avg_times = map_dict(merge_times, t => am(t.values()))


#let speed_ff = image("diagrams/ff.svg")
#let speed_ff_ = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // x-tick-step: 2,
    x-min: -0.02,
    x-max: 100,
    label-key: 0,
    value-key: (..range(1, 8)),
    // value-key: (..range(1, 4)),
    axis-style: "scientific",
    bar-style: idx => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx)),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      // [without optimisations],
      // [with optimisations]
    ),
    // x-unit: [x],
    x-label: [Time taken to transform all events (ms). (lower is better)],
    (
      (
        "Optimization off",
        datasets.map(name => timings.dt_ff_off.at(name)),
      ).flatten(),
      (
        "Optimization on",
        datasets.map(name => timings.dt_merge_norm.at(name)),
      ).flatten(),
    ),
  )
})

#let speed_merge = image("diagrams/timings.svg")
#let speed_merge_ = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // x-tick-step: 2,
    x-min: -0.02,
    x-max: 700,
    label-key: 0,
    value-key: (..range(1, 8)),
    // value-key: (..range(1, 4)),
    axis-style: "scientific",
    bar-style: idx => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx))
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      // [eg-walker],
      // [dt-crdt],
      // [automerge]
      // [dt-crdt], [dt]
    ),
    // x-unit: [x],
    x-label: [Merge time taken in milliseconds (lower is better)],
    algorithms.map(alg => (
      algnames.at(alg),
      datasets.map(name => merge_times.at(alg).at(name)),
    ).flatten()),
  )
})

#let speed_load_ = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // x-tick-step: 2,
    x-min: -0.02,
    x-max: 700,
    label-key: 0,
    value-key: (..range(1, 8)),
    // value-key: (..range(1, 4)),
    axis-style: "scientific",
    bar-style: idx => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx))
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      // [eg-walker],
      // [dt-crdt],
      // [automerge]
      // [dt-crdt], [dt]
    ),
    // x-unit: [x],
    x-label: [Load time in milliseconds (lower is better)],
    algorithms.map(alg => (
      algnames.at(alg),
      datasets.map(name => load_times.at(alg).at(name)),
    ).flatten()),
  )
})


// **** RAM usage

#let mb = 1e6

#let dtmem = json("results/dt_memusage.json")
#let dtcrdtmem = json("results/dtcrdt_memusage.json")
#let otmem = json("results/ot_memusage.json")
#let yjsmem = json("results/yjs_memusage.json")
#let ammem = json("results/automerge_memusage.json")

#let mem_data = (
  dt: dtmem,
  dtcrdt: dtcrdtmem,
  ot: otmem,
  yjs: yjsmem,
  automerge: ammem,
)

#let avg_mem = map_dict(mem_data, m => (
  steady_state: am(m.values().map(x => x.steady_state)),
  peak: am(m.values().map(x => x.peak)),
))

#let all_mem_data = (
  dt_steady: datasets.map(ds => dtmem.at(ds).steady_state),
  dt_peak: datasets.map(ds => dtmem.at(ds).peak),
  ot_steady: datasets.map(ds => otmem.at(ds).steady_state),
  ot_peak: datasets.map(ds => otmem.at(ds).peak),

  dtcrdt: datasets.map(ds => dtcrdtmem.at(ds).peak),
  yjs: datasets.map(ds => yjsmem.at(ds).peak),
  automerge: datasets.map(ds => ammem.at(ds).peak),
)

#let all_mem_names = (
  dt_peak: "Eg-walker (peak)",
  dt_steady: "Eg-walker (steady)",
  ot_peak: "OT (peak)",
  ot_steady: "OT (steady)",

  dtcrdt: algnames.dtcrdt,
  yjs: algnames.yjs,
  automerge: algnames.automerge,
)

#let memusage_peak = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // x-tick-step: 0.5,
    // x-tick-step: 50,
    x-min: -0.1,
    x-max: 600,
    // x-max: 600,
    label-key: 0,
    // value-key: (..range(1, 6)),
    value-key: (..range(1, 8)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx))
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
    ),
    // x-unit: [x],
    x-label: [Peak memory usage in MB (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
    algorithms.map(alg => (
      algnames.at(alg),
      datasets.map(name => mem_data.at(alg).at(name).peak / mb),
    ).flatten()),
  )
})

#let memusage_steady = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // x-tick-step: 0.5,
    // x-tick-step: 50,
    x-min: -0.1,
    x-max: 90,
    // x-max: 600,
    label-key: 0,
    // value-key: (..range(1, 6)),
    value-key: (..range(1, 8)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx))
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
    ),
    // x-unit: [x],
    x-label: [Steady state memory usage in MB (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
    algorithms.map(alg => (
      algnames.at(alg),
      datasets.map(name => mem_data.at(alg).at(name).steady_state / mb),
    ).flatten()),
  )
})


#let memusage_all = image("diagrams/memusage.svg")
#let memusage_all_ = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 10,
    // x-tick-step: 0.5,
    // x-tick-step: 50,
    x-min: -0.1,
    x-max: 150,
    // x-max: 600,
    label-key: 0,
    value-key: (..range(1, 8)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx))
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
    ),
    // x-unit: [x],
    x-label: [Memory usage in MB (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
    all_mem_names.keys().map(alg => (
      all_mem_names.at(alg),
      datasets.map(name => all_mem_data.at(alg).map(val => val / mb)),
    ).flatten()),
    // (
    //   "dt-steady", "dt-peak", "ot-steady", "ot-peak", "dtcrdt", "yjs", "automerge"
    // ).map(alg => (
    //   alg,
    //   // algnames.at(alg),
    //   datasets.map(name => mem_data.at(alg).at(name).steady_state / mb),
    // ).flatten()),
  )
})


// ****** FILE SIZES

#let yjs_am_sizes = json("results/yjs_am_sizes.json")
#let dt_stats = json("results/dataset_stats.json")
#let big_filesizes = (
  dt: datasets.map(ds => dt_stats.at(ds).uncompressed_size / mb),
  automerge: datasets.map(ds => yjs_am_sizes.at(ds).automergeUncompressed / mb),
)
#let big_filesizes_overhead = (
  dt: datasets.map(ds => (dt_stats.at(ds).uncompressed_size - dt_stats.at(ds).ins_content_len_utf8) / mb),
  automerge: datasets.map(ds => (yjs_am_sizes.at(ds).automergeUncompressed - dt_stats.at(ds).ins_content_len_utf8) / mb),
)
#let smol_filesizes = (
  dt: datasets.map(ds => dt_stats.at(ds).uncompressed_smol_size / mb),
  yjs: datasets.map(ds => yjs_am_sizes.at(ds).yjs / mb),
)

#let filesize_full = image("diagrams/filesize_full.svg")
#let filesize_full_ = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 0.5,
    // x-tick-step: 50,
    x-min: -0.004,
    x-max: 4,
    label-key: 0,
    // value-key: (..range(1, 6)),
    value-key: (..range(1, 8)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx))
      // fill: (red, green, blue, yellow).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      // [Eg-walker (full)], [Automerge]
    ),
    // x-unit: [x],
    x-label: [File size in MB (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
    (
      ("(Raw size)", ..datasets.map(ds => dt_stats.at(ds).ins_content_len_utf8 / mb)),
      ..("dt", "automerge").map(alg => (
        algnames.at(alg),
        ..big_filesizes.at(alg),
      ))
    ),
  )
})

// #let filesize_full = canvas(length: 1cm, {
//   draw.set-style(barchart: barchart_style)
//   draw.set-style(barchart: ( legend: (
//     // default-position: "legend.north-east",
//     default-position: "legend.inner-north-east",
//   )))
//   chart.barchart(
//     mode: "clustered",
//     // mode: "basic",
//     size: (7, 4),
//     x-tick-step: 0.5,
//     // x-tick-step: 50,
//     x-min: -0.004,
//     x-max: 4,
//     label-key: 0,
//     // value-key: (..range(1, 6)),
//     value-key: (..range(1, 8)),
//     axis-style: "scientific",
//     bar-style: (idx) => (
//       stroke: 0.1pt + black,
//       fill: dscolors.at(datasets.at(idx))
//       // fill: (red, green, blue, yellow).at(idx),
//     ),
//     // plot-args: (
//     //   plot-style: black
//     // ),
//     labels: (
//       // [Eg-walker (full)], [Automerge]
//     ),
//     // x-unit: [x],
//     x-label: [File size in MB (lower is better)],
//     // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
//     (
//       ("(Raw size)", ..datasets.map(ds => dt_stats.at(ds).ins_content_len_utf8 / mb)),
//       ..("dt", "automerge").map(alg => (
//         algnames.at(alg),
//         big_filesizes.at(alg),
//       ).flatten())
//     ),
//   )
// })

#let filesize_smol = image("diagrams/filesize_smol.svg")
#let filesize_smol_ = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 0.5,
    // x-tick-step: 50,
    x-min: -0.002,
    x-max: 3,
    label-key: 0,
    // value-key: (..range(1, 6)),
    value-key: (..range(1, 8)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: dscolors.at(datasets.at(idx))
      // fill: (red, green, blue, yellow).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      // [Eg-walker (full)], [Automerge]
    ),
    // x-unit: [x],
    x-label: [File size in MB (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
    (
      ("(Raw size)", ..datasets.map(ds => dt_stats.at(ds).final_doc_len_utf8 / mb)),
      ..("dt", "yjs").map(alg => (
        algnames.at(alg),
        smol_filesizes.at(alg),
      ).flatten())
    ),
  )
})

#let filesize_full2 = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 0.5,
    // x-tick-step: 50,
    x-min: -0.004,
    x-max: 4,
    label-key: 0,
    // value-key: (..range(1, 6)),
    value-key: (..range(1, 3)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: (
        // red, fuchsia,
        algcolors.dt,
        algcolors.automerge,
      ).at(idx),
      // fill: (red, green, blue, yellow).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      // [(raw document)],
      // [(insert length)],
      // [dt-uncompressed], [automerge-uncompressed],
      [Eg-walker (full)], [Automerge]
    ),
    // x-unit: [x],
    x-label: [File size in MB (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
    (
      "S1", "S2", "S3", "C1", "C2", "A1", "A2"
    ).map(name => (
      name,
      dt_stats.at(name).uncompressed_size / mb,
      yjs_am_sizes.at(name).automergeUncompressed / mb,
    )),
  )
})

#let filesize_smol2 = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // x-tick-step: 1,
    // x-minor-tick-step: 0.5,
    x-tick-step: 0.5,
    x-min: -0.002,
    x-max: 3,
    label-key: 0,
    value-key: (..range(1, 3)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: (
        // red, //luma(90%),
        algcolors.dt,
        algcolors.yjs,
      ).at(idx),
      // fill: (red, green, blue, yellow).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      [Eg-walker (small)], [Yjs],
    ),
    // x-unit: [x],
    x-label: [File size in MB (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to final document length. (Smaller is better)]),
    (
      "S1", "S2", "S3", "C1", "C2", "A1", "A2"
    ).map(name => (
      name,

      dt_stats.at(name).uncompressed_smol_size / mb,
      yjs_am_sizes.at(name).yjs / mb,
    )),
  )
})

