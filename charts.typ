// This file contains charts for reg-text.typ. Its awkward including them inline, so I've moved
// them here.

// #import "@local/cetz:0.2.0": canvas, plot, draw, chart, palette, styles
#import "@preview/cetz:0.2.0": canvas, plot, draw, chart, palette, styles


#let alg-colors = (
  dt: maroon,
  dtcrdt: red.desaturate(60%),
  yjs: aqua,
  automerge: yellow,
  cola: fuchsia,
  cola-nocursor: fuchsia.desaturate(70%),
  jsonjoy: olive,
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
      plot.add(scale_data("results/xf-friendsforever-noff.json", 0.001), label: [without optimisations])
      plot.add(scale_data("results/xf-friendsforever-ff.json", 0.001), label: [with optimisations])
    }
  )
})

// *** SPEEEED

#let raw_timings = json("results/timings.json")

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

#let num_patches = json("results/numpatches.json")
#let bar_for_local(stat_name, name) = {
  (
    // text(8pt, name),
    name,
    num_patches.at(name) / raw_timings.at("dt-crdt_local").at(name) / 1000,
    num_patches.at(name) / raw_timings.at("dt_local").at(name) / 1000,
    // num_patches.at(name) / raw_timings.at("dt_local_rle").at(name) / 1000,
  )
}


// #let speed_local = canvas(length: 1cm, {
//   draw.set-style(barchart: barchart_style)
//   chart.barchart(
//     mode: "clustered",
//     // mode: "basic",
//     size: (7, 4),
//     value-key: (..range(1, 3)),
//     labels: (
//       // [dt-crdt], [dt]
//       [crdt (dt-crdt)], [eg-walker (dt)]
//     ),
//     axis-style: "scientific",
//     bar-style: idx => (
//       stroke: 0.1pt + black,
//       fill: (alg-colors.dtcrdt, alg-colors.dt).at(idx),
//     ),
//     // bar-style: palette.tango,
//     // x-unit: [x],
//     x-label: [Local speed in Mevents / sec processed (higher is better)],
//     x-max: 75,
//     x-min: -0.08,
//     x-tick-step: 10,
//     plot-args: (
//       // x-ticks: (10, 20),
//     ),
//     (
//       bar_for_local("automerge-paper", "automerge-paper"),
//       bar_for_local("seph-blog1", "seph-blog1"),
//       bar_for_local("egwalker", "egwalker"),
//       bar_for_local("clownschool", "clownschool_flat"),
//       bar_for_local("friendsforever", "friendsforever_flat"),
//       // bar_for_local("node_nodecc"),
//       // bar_for_local("git-makefile"),
//     ),
//   )
// })




#let bar_for_remote(name) = {
  let stats = json("results/stats_" + name + ".json")
  (
    name,
    stats.op_stats.len / raw_timings.at("dt_merge").at(name) / 1000,
    stats.op_stats.len / raw_timings.at("dt-crdt_process_remote_edits").at(name) / 1000,
    stats.op_stats.len / raw_timings.at("automerge_remote").at(name, default: 100000) / 1000,
  )
}

#let speed_remote = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 2,
    x-min: -0.02,
    x-max: 18,
    label-key: 0,
    value-key: (..range(1, 3)),
    // value-key: (..range(1, 4)),
    axis-style: "scientific",
    bar-style: idx => (
      stroke: 0.1pt + black,
      fill: (
        alg-colors.dt,
        alg-colors.dtcrdt,
        alg-colors.automerge
      ).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      [eg-walker],
      [dt-crdt],
      // [automerge]
      // [dt-crdt], [dt]
    ),
    // x-unit: [x],
    x-label: [Replay/merge throughput in Mevents/sec (higher is better)],
    (
      bar_for_remote("automerge-paper"),
      bar_for_remote("seph-blog1"),
      bar_for_remote("egwalker"),
      bar_for_remote("friendsforever"),
      bar_for_remote("clownschool"),
      bar_for_remote("node_nodecc"),
      bar_for_remote("git-makefile"),
    ),
  )
})


#let bar_for_ff(name) = {
  let stats = json("results/stats_" + name + ".json")
  (
    name,
    1,
    1 * raw_timings.at("dt_ff_off").at(name) / raw_timings.at("dt_ff_on").at(name)
    // stats.op_stats.len / raw_timings.at("dt_ff_off").at(name) / 1000,
    // stats.op_stats.len / raw_timings.at("dt_ff_on").at(name) / 1000,
  )
}

#let speed_ff = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // x-tick-step: 2,
    x-min: -0.02,
    x-max: 17,
    label-key: 0,
    value-key: (..range(1, 3)),
    // value-key: (..range(1, 4)),
    axis-style: "scientific",
    bar-style: idx => (
      stroke: 0.1pt + black,
      fill: (
        blue,
        green,
      ).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      [without optimisations],
      [with optimisations]
    ),
    // x-unit: [x],
    x-label: [Normalised replay throughput (higher is better)],
    (
      bar_for_ff("automerge-paper"),
      bar_for_ff("seph-blog1"),
      bar_for_ff("egwalker"),
      bar_for_ff("friendsforever"),
      bar_for_ff("clownschool"),
      bar_for_ff("node_nodecc"),
      bar_for_ff("git-makefile"),
    ),
  )
})






// ************** ALL ALGORITHMS

#let jsstats = json("results/js.json")

// #let bar_for_all_local(stat_name, name) = {

//   // Dividing by 1000 to put results in Mops/sec instead of Kops/sec.

//   (
//     // text(8pt, name),
//     name,
//     num_patches.at(name) / raw_timings.at("dt-crdt_local").at(name) / 1000,
//     num_patches.at(name) / raw_timings.at("dt_local").at(name) / 1000,
//     num_patches.at(name) / raw_timings.at("automerge_local").at(name) / 1000,
//     num_patches.at(name) / raw_timings.at("cola_local").at(name) / 1000,
//     num_patches.at(name) / raw_timings.at("cola-nocursor_local").at(name) / 1000,
//     num_patches.at(name) / jsstats.at("jsonjoy/local/" + name).meanTime / 1000,
//     num_patches.at(name) / jsstats.at("yjs/local/" + name).meanTime / 1000,

//     // num_patches.at(name) / raw_timings.at("dt_local_rle").at(name) / 1000,
//   )
// }


#let all_speed_local = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    // value-key: (..range(1, bar_for_all_local("automerge-paper", "automerge-paper").len())),
    value-key: (..range(1, 8)),
    labels: (
      [dt],
      [dt-crdt],
      [automerge], [cola], [cola-nocursor], [json-joy (js)], [yjs (js)]
    ),
    axis-style: "scientific",
    bar-style: idx => (
      stroke: 0.1pt + black,
      fill: (
        alg-colors.dt,
        alg-colors.dtcrdt,
        alg-colors.automerge,
        alg-colors.cola,
        alg-colors.cola-nocursor,
        alg-colors.jsonjoy,
        alg-colors.yjs,
      ).at(idx),
    ),
    // bar-style: palette.tango,
    // x-unit: [x],
    x-label: [Local speed in Mevents / sec processed. More is better],
    x-max: 90,
    x-min: -0.08,
    x-tick-step: 10,
    plot-args: (
      // x-ticks: (10, 20),
    ),
    (
      ("automerge-paper", "automerge-paper"),
      ("seph-blog1", "seph-blog1"),
      ("egwalker", "egwalker"),
      ("clownschool", "clownschool_flat"),
      ("friendsforever", "friendsforever_flat"),
      // bar_for_all_local("node_nodecc"),
      // bar_for_all_local("git-makefile"),
    ).map(((stat_name, name)) => (
      name,
      num_patches.at(name) / raw_timings.at("dt_local").at(name) / 1000,
      num_patches.at(name) / raw_timings.at("dt-crdt_local").at(name) / 1000,
      num_patches.at(name) / raw_timings.at("automerge_local").at(name) / 1000,
      num_patches.at(name) / raw_timings.at("cola_local").at(name) / 1000,
      num_patches.at(name) / raw_timings.at("cola-nocursor_local").at(name) / 1000,
      num_patches.at(name) / jsstats.at("jsonjoy/local/" + name).meanTime / 1000,
      num_patches.at(name) / jsstats.at("yjs/local/" + name).meanTime / 1000,
    )),
    // (
    //   bar_for_all_local("automerge-paper", "automerge-paper"),
    //   bar_for_all_local("seph-blog1", "seph-blog1"),
    //   bar_for_all_local("clownschool", "clownschool_flat"),
    //   bar_for_all_local("friendsforever", "friendsforever_flat"),
    //   // bar_for_all_local("node_nodecc"),
    //   // bar_for_all_local("git-makefile"),
    // ),
  )
})


#let bar_for_one_local(stat_name, name) = {
  // Dividing by 1000 to put results in Mops/sec instead of Kops/sec.

  (
    // text(8pt, name),
    ("dt-crdt", num_patches.at(name) / raw_timings.at("dt-crdt_local").at(name) / 1000),
    ([automerge@automerge], num_patches.at(name) / raw_timings.at("automerge_local").at(name) / 1000),
    ([yjs@yjs], num_patches.at(name) / jsstats.at("yjs/local/" + name).meanTime / 1000),
    ([cola@cola], num_patches.at(name) / raw_timings.at("cola_local").at(name) / 1000),
    ("cola-nocursor", num_patches.at(name) / raw_timings.at("cola-nocursor_local").at(name) / 1000),
    // num_patches.at(name) / raw_timings.at("dt_local").at(name) / 1000,
    ([json-joy@jsonjoy], num_patches.at(name) / jsstats.at("jsonjoy/local/" + name).meanTime / 1000),

    // num_patches.at(name) / raw_timings.at("dt_local_rle").at(name) / 1000,
  )
}


#let one_local = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    bar_for_one_local("seph-blog1", "seph-blog1"),
    // (("x", 1),("y", 2),("z", 3)),
    mode: "basic",
    // mode: "basic",
    size: (7, 4),
    // value-key: (..range(1, bar_for_all_local("automerge-paper", "automerge-paper").len())),
    // value-key: (..range(1, 7)),
    // labels: (
    //   [dt-crdt], [dt], [automerge], [cola], [cola-nocursor], [json-joy (js)], [yjs (js)]
    // ),
    axis-style: "scientific",
    bar-style: idx => (
      stroke: 0.1pt + black,
      fill: (
        alg-colors.dtcrdt,
        alg-colors.automerge,
        alg-colors.yjs,
        alg-colors.cola,
        alg-colors.cola.desaturate(70%),
        alg-colors.jsonjoy,
        // alg-colors.dt,
      ).at(idx),
    ),
    // bar-style: palette.tango,
    // x-unit: [x],
    x-label: [Local event replay throughput in Mevents/sec (higher is better)],
    x-max: 35,
    x-min: -0.02,
    x-tick-step: 10,
    plot-args: (
      // x-ticks: (10, 20),
    ),
  )
})




#let bar_for_all_remote(name) = {
  let stats = json("results/stats_" + name + ".json")
  (
    name,
    stats.op_stats.len / raw_timings.at("dt-crdt_process_remote_edits").at(name) / 1000,
    // stats.op_stats.len / raw_timings.at("dt_merge").at(name) / 1000,
    stats.op_stats.len / jsstats.at("yjs/remote/" + name).meanTime / 1000,
    stats.op_stats.len / raw_timings.at("automerge_remote").at(name, default: 100000) / 1000,
  )
}

#let all_speed_remote = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 2,
    x-min: -0.002,
    x-max: 3,
    label-key: 0,
    // value-key: (..range(1, 5)),
    value-key: (..range(1, 4)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: (
        alg-colors.dtcrdt,
        alg-colors.yjs,
        alg-colors.automerge,
      ).at(idx),
      // fill: (red, green, blue, yellow).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      [dt-crdt], [yjs], [automerge]
      // [crdt (dt-crdt)], [eg-walker (dt)], [automerge], [yjs]
    ),
    // x-unit: [x],
    x-label: [Merge throughput in Mevents/sec (higher is better)],
    (
      "automerge-paper",
      "seph-blog1",
      "egwalker",
      "friendsforever",
      "clownschool",
      "node_nodecc",
      // bar_for_all_remote("node_nodecc"),
      // bar_for_all_remote("git-makefile"),
    ).map(bar_for_all_remote),
  )
})



// ****** FILE SIZES

#let filesizes = json("results/filesizes.json")

#let filesize_full = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 1,
    // x-tick-step: 50,
    x-min: -0.004,
    x-max: 8,
    label-key: 0,
    // value-key: (..range(1, 6)),
    value-key: (..range(1, 3)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: (
        // red, fuchsia,
        alg-colors.dt,
        alg-colors.automerge,
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
    x-label: [Ratio of file size to inserted text content length (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to total inserted content length. (Smaller is better)]),
    (
      "automerge-paper",
      "seph-blog1",
      "egwalker",
      "friendsforever",
      "clownschool",
      "node_nodecc",
      // bar_for_all_remote("node_nodecc"),
      // bar_for_all_remote("git-makefile"),
    ).map(name => (
      name,
      // filesizes.at(name).docLen / 1024,
      // filesizes.at(name).insLen / 1024,
      1 * (filesizes.at(name).uncompressedSize / filesizes.at(name).insLen - 0),
      1 * (filesizes.at(name).amSizeUncompressed / filesizes.at(name).insLen - 0),
      // filesizes.at(name).size / 1024,
      // filesizes.at(name).amSize / 1024,
    )),
  )
})

// #let filesize_full = canvas(length: 1cm, {
//   draw.set-style(barchart: barchart_style)
//   chart.barchart(
//     mode: "clustered",
//     // mode: "basic",
//     size: (7, 4),
//     x-tick-step: 50,
//     x-min: -0.4,
//     x-max: 400,
//     label-key: 0,
//     // value-key: (..range(1, 6)),
//     value-key: (..range(1, 5)),
//     axis-style: "scientific",
//     bar-style: (idx) => (
//       stroke: 0.1pt + black,
//       fill: (
//         red, fuchsia,
//         alg-colors.dt,
//         alg-colors.automerge,
//       ).at(idx),
//       // fill: (red, green, blue, yellow).at(idx),
//     ),
//     // plot-args: (
//     //   plot-style: black
//     // ),
//     labels: (
//       [(raw document)],
//       [(insert length)],
//       // [dt-uncompressed], [automerge-uncompressed],
//       [DT], [Automerge]
//     ),
//     // x-unit: [x],
//     x-label: text(10pt, [Uncompressed file size in KB (Smaller is better)]),
//     (
//       "automerge-paper",
//       "seph-blog1",
//       "friendsforever",
//       "clownschool",
//       // "node_nodecc",
//       // bar_for_all_remote("node_nodecc"),
//       // bar_for_all_remote("git-makefile"),
//     ).map(name => (
//       name,
//       filesizes.at(name).docLen / 1024,
//       filesizes.at(name).insLen / 1024,
//       filesizes.at(name).uncompressedSize / 1024,
//       filesizes.at(name).amSizeUncompressed / 1024,
//       filesizes.at(name).size / 1024,
//       filesizes.at(name).amSize / 1024,
//     )),
//   )
// })

#let filesize_smol = canvas(length: 1cm, {
  draw.set-style(barchart: barchart_style)
  draw.set-style(barchart: ( legend: (
    // default-position: "legend.north-east",
    default-position: "legend.inner-north-east",
  )))
  chart.barchart(
    mode: "clustered",
    // mode: "basic",
    size: (7, 4),
    x-tick-step: 1,
    // x-minor-tick-step: 0.5,
    // x-tick-step: 100,
    x-min: -0.002,
    x-max: 10.40,
    label-key: 0,
    value-key: (..range(1, 3)),
    axis-style: "scientific",
    bar-style: (idx) => (
      stroke: 0.1pt + black,
      fill: (
        // red, //luma(90%),
        alg-colors.dt,
        alg-colors.yjs,
      ).at(idx),
      // fill: (red, green, blue, yellow).at(idx),
    ),
    // plot-args: (
    //   plot-style: black
    // ),
    labels: (
      // [(raw document)],
      [Eg-walker (small)], [Yjs],
      // [crdt (dt-crdt)], [eg-walker (dt)], [automerge], [yjs]
    ),
    // x-unit: [x],
    x-label: [Ratio of file size to current document length (lower is better)],
    // x-label: text(10pt, [% file size overhead compared to final document length. (Smaller is better)]),
    (
      "automerge-paper",
      "seph-blog1",
      "egwalker",
      "friendsforever",
      "clownschool",
      "node_nodecc",
      // bar_for_all_remote("node_nodecc"),
      // bar_for_all_remote("git-makefile"),
    ).map(name => (
      name,
      1 * (filesizes.at(name).uncompressedSmolSize / filesizes.at(name).docLen - 0),
      1 * (filesizes.at(name).yjsSize / filesizes.at(name).docLen - 0),
      // filesizes.at(name).docLen / 1024,
      // filesizes.at(name).uncompressedSmolSize / 1024,
      // filesizes.at(name).yjsSize / 1024,
    )),
  )
})

// #let filesize_smol = canvas(length: 1cm, {
//   draw.set-style(barchart: barchart_style)
//   chart.barchart(
//     mode: "clustered",
//     // mode: "basic",
//     size: (7, 4),
//     x-tick-step: 50,
//     x-min: -0.2,
//     x-max: 200,
//     label-key: 0,
//     value-key: (..range(1, 4)),
//     axis-style: "scientific",
//     bar-style: (idx) => (
//       stroke: 0.1pt + black,
//       fill: (
//         red, //luma(90%),
//         alg-colors.dt,
//         alg-colors.yjs,
//       ).at(idx),
//       // fill: (red, green, blue, yellow).at(idx),
//     ),
//     // plot-args: (
//     //   plot-style: black
//     // ),
//     labels: (
//       [(raw document)],
//       [DT], [Yjs],
//       // [crdt (dt-crdt)], [eg-walker (dt)], [automerge], [yjs]
//     ),
//     // x-unit: [x],
//     x-label: text(10pt, [Uncompressed file size in KB, without deleted content (Smaller is better)]),
//     (
//       "automerge-paper",
//       "seph-blog1",
//       "friendsforever",
//       "clownschool",
//       // "node_nodecc",
//       // bar_for_all_remote("node_nodecc"),
//       // bar_for_all_remote("git-makefile"),
//     ).map(name => (
//       name,
//       filesizes.at(name).docLen / 1024,
//       filesizes.at(name).uncompressedSmolSize / 1024,
//       filesizes.at(name).yjsSize / 1024,
//     )),
//   )
// })
