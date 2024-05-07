import * as Plot from '@observablehq/plot'
import * as d3 from 'd3'
import fs from 'fs'
import {JSDOM} from "jsdom";

const {window} = new JSDOM("")

const anonymous = true
const egwalkerName = anonymous ? 'Feathertail' : 'Eg-walker'

const savePlot = (plot, filename) => {
  // plot.setAttribute('style', "background-color:green")
  // plot.setAttribute('fill', "green")

  // const svg = window.document.createElement('svg')
  plot.setAttribute('xmlns', "http://www.w3.org/2000/svg")
  plot.setAttribute('xmlns:xlink', "http://www.w3.org/1999/xlink")
  plot.setAttribute('version', "1.1")

  // console.log(plot.outerHTML)
  // console.log(plot.innerHTML)
  // plot.
  fs.writeFileSync('../diagrams/' + filename, plot.outerHTML)
}

const loadJson = filename => JSON.parse(fs.readFileSync(filename, 'utf8'))
const rawTimings = loadJson('../results/timings.json')


let datasets = ["S1", "S2", "S3", "C1", "C2", "A1", "A2"]

  // "automerge-paperx3",
  // "seph-blog1x3",
  // "node_nodeccx1",
  // "friendsforeverx25",
  // "clownschoolx25",
  // "egwalkerx1",
  // "git-makefilex2",
// ]

const dstype = { "S1": 'seq', "S2": 'seq', "A1": 'async', "A2": 'async', "C1": 'conc', "C2": 'conc', "S3": 'seq', }

const formatMs = (ms) => (
  // ms < 1 ? `${roundAuto(ms * 1000)} μs`
      ms < 1000 ? `${roundAuto(ms)} ms`
      : ms < 60*1000 ? `${roundAuto(ms / 1000)} sec`
      : `${roundAuto(ms / (60 * 1000))} min`
)

const KB = 1024
const MB = 1024 * 1024
const GB = 1024 * 1024 * 1024

const KiB = 1000
const MiB = 1000 * 1000
const GiB = 1000 * 1000 * 1000

const formatBytes = b => (
  b >= GiB ? `${roundAuto(b/GiB)} GiB`
  : b >= MiB ? `${roundAuto(b/MiB)} MiB`
  : b >= KiB ? `${roundAuto(b/KiB)} KiB`
  : `${roundAuto(b)} B`
)
// const formatBytes = b => (
//   b >= GB ? `${roundAuto(b/GB)} GB`
//   : b >= MB ? `${roundAuto(b/MB)} MB`
//   : b >= KB ? `${roundAuto(b/KB)} KB`
//   : `${roundAuto(b)} B`
// )

const roundN = (n, digits) => {
  const m = Math.pow(10, digits)
  return Math.round(n * m) / m
}

const roundAuto = n => {
  const digits = n < 1 ? 2
    : n > 100 ? 0
    : 1
  return roundN(n, digits)
}


const plotTimes = () => {
  const algnames = {
    dt: egwalkerName,

    dtmerge: `${egwalkerName}\n(merge)`,
    dtload: `${egwalkerName}\n(load)`,

    ot: 'OT',

    otmerge: "OT\n(merge)",
    otload: "OT\n(load)",

    dtcrdt: "Ref CRDT",
    yjs: "Yjs",
    automerge: "Automerge"
  }


  const data = [
    ...datasets.map(name => ({ dataset: name, type: 'dtmerge', val: rawTimings.dt_merge_norm[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'dtload', val: rawTimings.dt_opt_load[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'otmerge', val: rawTimings.ot[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'otload', val: rawTimings.dt_opt_load[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'dtcrdt', val: rawTimings['dt-crdt_process_remote_edits'][name], })),
    ...datasets.map(name => ({ dataset: name, type: 'automerge', val: rawTimings.automerge_remote[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'yjs', val: rawTimings.yjs_remote[name], })),
  ]

  // console.log(data)

  const baseline = 1.2

  return Plot.plot({
    figure: false,
    document: window.document,
    // marginLeft: 130,
    marginLeft: 110,
    // marginRight: 60,
    // marginBottom: 40,
    width: 500,
    height: 500,
    style: {
      background: 'white',
      // 'background-color': 'green',
      // "font-size": "14px",
      'font-family': 'Helvetica Neue, Helvetica, Arial, sans-serif',
    },
    // fy: {
    //   // tickRotate: '-90',
    //   label: null,
    //   tickFormat: (d, i, _) => algnames[d],
    //   // axis: 'left',
    // },
    y: {
      // label: 'Algorithm',
      // label: null,
      // domain: data.map(d => d.dataset),
      axis: null,
      // tickFormat: 's',
      // inset: 0.1,

    },
    x: {
      label: 'Time taken (in milliseconds) to merge and reload changes. Log scale. (Less is better)',
      fontSize: "20px",
      grid: true,
      domain: [baseline, 37000000],
      // type: 'linear',
      // nice: true,
      type: 'log',
      axis: 'bottom',
      tickSpacing: 50,
      // marginBottom: 40,
      // labelOffset: 40,
      // tickFormat: '1s',
      // tickSize: 4,
      // tickSpacing: 40,
      // strokeOpacity: 1,
      // tickFormat: (a, b, c) => `${formatMs(a)}`,
    },
    color: {
      scheme: "Dark2"
    },
    marks: [
      Plot.gridX({
        strokeWidth: 0.5,
        strokeOpacity: 0.15,
        tickSpacing: 45,
      }),
      Plot.axisY({
        // textAnchor: 'start',
        // fill: 'white',
        // dx: 10,
        // ticks: null,
        label: null,
        fontSize: 8
      }),
      // Plot.frame({
      //   fy: 'dt',
      //   // stroke: null,
      //   fill: 'green',
      //   opacity: 0.1,
      // }),
      Plot.barX(data, {
        y: 'dataset',
        fy: 'type',
        x1: baseline,
        x2: d => Math.max(d.val, baseline),
        // fill: 'type',
        fill: d => dstype[d.dataset],
        // sort: null,
        sort: {y: null, color: null, fy: {type: "x"}},
        // sort: d => ord.indexOf(d.dataset)
      }),
      Plot.axisFy({
        fontSize: '15px',
        label: null,
        anchor: 'left',
        dx: -17,
        tickFormat: (d, i, _) => algnames[d],
        lineHeight: 1.2,
      }),
      Plot.ruleX([1000/60], {stroke: '#800000', strokeOpacity: 0.5}),
      Plot.tickX(data, {fy: 'type', x: d => Math.max(d.val, baseline), y: "dataset"}),
      Plot.text(data, {
        y: 'dataset', fy: 'type',
        x: d => Math.max(d.val, baseline),
        // text: d => d.val < baseline ? '<1ms' : `${formatMs(d.val)}`,
        text: d => `${formatMs(d.val)}`,
        fontSize: 9,
        textAnchor: 'start',
        fill: 'black',
        dx: 6,
      }),
      // Plot.text(data, {
      //   y: 'dataset', fy: 'type',
      //   x: baseline,
      //   textAnchor: 'start',
      //   dx: 3,
      //   fontWeight: 800,
      //   text: d => d.dataset,
      //   fill: 'white',
      // }),
      // Plot.text(data, {y: 'dataset', fy: 'type', text: (d) => (d.val * 100).toFixed(1), dx: -6, lineAnchor: "bottom"}),

      // Plot.text(data, {
      //   text: d => `${Math.floor(d.value / 1000)} ms`,
      //   y: "type",
      //   x: "val",
      //   textAnchor: "end",
      //   dx: -3,
      //   fill: "white"
      // }),
      // Plot.text(data, {x: 'val', y: 'type', text: 'asdf', textAnchor: 'end', dx: 5}),
      Plot.ruleX([baseline], {strokeWidth: 1.5}),
      // Plot.ruleX([baseline], {
      //   dx: -22,
      //   strokeWidth: 1.5
      // }),
      // Plot.ruleY([0]),
    ]
  })
}


const plotMemusage = () => {
  const algnames = {
    dtsteady: `${egwalkerName}\n(steady)`,
    dtpeak: `${egwalkerName}\n(peak)`,

    otsteady: "OT\n(steady)",
    otpeak: "OT\n(peak)",

    dtcrdt: "Ref CRDT",
    yjs: "Yjs",
    automerge: "Automerge"
  }

  const dtmem = loadJson("../results/dt_memusage.json")
  const dtcrdtmem = loadJson("../results/dtcrdt_memusage.json")
  const otmem = loadJson("../results/ot_memusage.json")
  const yjsmem = loadJson("../results/yjs_memusage.json")
  const ammem = loadJson("../results/automerge_memusage.json")

  const data = [
    ...datasets.map(dataset => ({ dataset, type: 'dtpeak', val: dtmem[dataset].peak, })),
    ...datasets.map(dataset => ({ dataset, type: 'dtsteady', val: dtmem[dataset].steady_state, })),
    ...datasets.map(dataset => ({ dataset, type: 'otpeak', val: otmem[dataset].peak, })),
    ...datasets.map(dataset => ({ dataset, type: 'otsteady', val: otmem[dataset].steady_state, })),

    // Steady and peak are basically the same for the CRDT data sets
    // ...datasets.map(dataset => ({ dataset, type: 'dtcrdtsteady', val: dtcrdtmem[dataset].steady_state, })),
    ...datasets.map(dataset => ({ dataset, type: 'dtcrdt', val: dtcrdtmem[dataset].peak, })),
    ...datasets.map(dataset => ({ dataset, type: 'yjs', val: yjsmem[dataset].peak, })),
    ...datasets.map(dataset => ({ dataset, type: 'automerge', val: ammem[dataset].peak, })),

    // ...datasets.map(dataset => ({ dataset, type: 'otmerge', val: rawTimings.ot[dataset], })),
    // ...datasets.map(dataset => ({ dataset, type: 'dtcrdt', val: rawTimings['dt-crdt_process_remote_edits'][dataset], })),
    // ...datasets.map(dataset => ({ dataset, type: 'automerge', val: rawTimings.automerge_remote[dataset], })),
    // ...datasets.map(dataset => ({ dataset, type: 'yjs', val: rawTimings.yjs_remote[dataset], })),
  ]

  // console.log(data)

  const baseline = 60 * KB

  return Plot.plot({
    figure: false,
    document: window.document,
    // marginLeft: 130,
    marginLeft: 110,
    // marginRight: 60,
    // marginBottom: 40,
    width: 500,
    height: 500,
    style: {
      background: 'white',
      // 'background-color': 'green',
      // "font-size": "14px",
      'font-family': 'Helvetica Neue, Helvetica, Arial, sans-serif',
    },
    // fy: {
    //   // tickRotate: '-90',
    //   label: null,
    //   tickFormat: (d, i, _) => algnames[d],
    //   // axis: 'left',
    // },
    y: {
      // label: 'Algorithm',
      // label: null,
      // domain: data.map(d => d.dataset),
      axis: null,
      // tickFormat: 's',
      // inset: 0.1,

    },
    x: {
      label: 'RAM used, log scale. (Less is better)',
      fontSize: "20px",
      grid: true,
      domain: [baseline, 100e9],
      // type: 'linear',
      // nice: true,
      type: 'log',
      axis: 'bottom',
      // tickSpacing: 50,
      // marginBottom: 40,
      // labelOffset: 40,
      // tickFormat: '1s',
      // tickSize: 4,
      // tickSpacing: 40,
      // strokeOpacity: 1,
      // tickFormat: (a, b, c) => (''+a).startsWith('1') ? formatBytes(a) : '',
      tickFormat: (a, b, c) => formatBytes(a),
    },
    color: {
      scheme: "Dark2"
    },
    marks: [
      Plot.gridX({
        strokeWidth: 0.5,
        strokeOpacity: 0.15,
        tickSpacing: 45,
      }),
      Plot.axisY({
        // textAnchor: 'start',
        // fill: 'white',
        // dx: 10,
        // ticks: null,
        label: null,
        fontSize: 8
      }),
      // Plot.frame({
      //   fy: 'dt',
      //   // stroke: null,
      //   fill: 'green',
      //   opacity: 0.1,
      // }),
      Plot.barX(data, {
        y: 'dataset',
        fy: 'type',
        x1: baseline,
        x2: d => Math.max(d.val, baseline),
        // fill: 'type',
        fill: d => dstype[d.dataset],
        // sort: null,
        sort: {y: null, color: null, fy: {type: "x"}},
        // sort: d => ord.indexOf(d.dataset)
      }),
      Plot.axisFy({
        fontSize: '15px',
        label: null,
        anchor: 'left',
        dx: -17,
        tickFormat: (d, i, _) => algnames[d],
        lineHeight: 1.2,
      }),
      Plot.ruleX([1000/60], {stroke: '#800000', strokeOpacity: 0.5}),
      Plot.tickX(data, {fy: 'type', x: d => Math.max(d.val, baseline), y: "dataset"}),
      Plot.text(data, {
        y: 'dataset', fy: 'type',
        x: d => Math.max(d.val, baseline),
        // text: d => d.val < baseline ? '<1ms' : `${formatMs(d.val)}`,
        text: d => `${formatBytes(d.val)}`,
        fontSize: 9,
        textAnchor: 'start',
        fill: 'black',
        dx: 6,
      }),
      // Plot.text(data, {
      //   y: 'dataset', fy: 'type',
      //   x: baseline,
      //   textAnchor: 'start',
      //   dx: 3,
      //   fontWeight: 800,
      //   text: d => d.dataset,
      //   fill: 'white',
      // }),
      // Plot.text(data, {y: 'dataset', fy: 'type', text: (d) => (d.val * 100).toFixed(1), dx: -6, lineAnchor: "bottom"}),

      // Plot.text(data, {
      //   text: d => `${Math.floor(d.value / 1000)} ms`,
      //   y: "type",
      //   x: "val",
      //   textAnchor: "end",
      //   dx: -3,
      //   fill: "white"
      // }),
      // Plot.text(data, {x: 'val', y: 'type', text: 'asdf', textAnchor: 'end', dx: 5}),
      Plot.ruleX([baseline], {strokeWidth: 1.5}),
      // Plot.ruleX([baseline], {
      //   dx: -22,
      //   strokeWidth: 1.5
      // }),
      // Plot.ruleY([0]),
    ]
  })
}


const yjs_am_sizes = loadJson("../results/yjs_am_sizes.json")
const dt_stats = loadJson("../results/dataset_stats.json")

const plotSize = (data, max) => {
  const algnames = {
    dt: `${egwalkerName}`,
    yjs: "Yjs",
    automerge: "Automerge"
  }

  return Plot.plot({
    figure: false,
    document: window.document,
    // marginLeft: 130,
    marginLeft: 110,
    // marginRight: 60,
    // marginBottom: 40,
    width: 500,
    height: 300,
    style: {
      background: 'white',
      // 'background-color': 'green',
      // "font-size": "14px",
      'font-family': 'Helvetica Neue, Helvetica, Arial, sans-serif',
    },
    // fy: {
    //   // tickRotate: '-90',
    //   label: null,
    //   tickFormat: (d, i, _) => algnames[d],
    //   // axis: 'left',
    // },
    y: {
      // label: 'Algorithm',
      // label: null,
      // domain: data.map(d => d.dataset),
      axis: null,
      // tickFormat: 's',
      // inset: 0.1,

    },
    x: {
      label: 'Encoded size (lower is better)',
      fontSize: "20px",
      grid: true,
      domain: [0, max],
      type: 'linear',
      // nice: true,
      // type: 'log',
      axis: 'bottom',
      // tickSpacing: 50,
      // marginBottom: 40,
      // labelOffset: 40,
      // tickFormat: '1s',
      // tickSize: 4,
      // tickSpacing: 40,
      // strokeOpacity: 1,
      // tickFormat: (a, b, c) => (''+a).startsWith('1') ? formatBytes(a) : '',
      tickFormat: (a, b, c) => formatBytes(a),
    },
    color: {
      scheme: "Dark2"
    },
    marks: [
      Plot.gridX({
        strokeWidth: 0.5,
        strokeOpacity: 0.15,
        tickSpacing: 45,
      }),
      Plot.axisY({
        // textAnchor: 'start',
        // fill: 'white',
        // dx: 10,
        // ticks: null,
        label: null,
        fontSize: 8
      }),
      // Plot.frame({
      //   fy: 'dt',
      //   // stroke: null,
      //   fill: 'green',
      //   opacity: 0.1,
      // }),
      Plot.barX(data, {
        y: 'dataset',
        fy: 'type',
        // x1: baseline,
        x: 'val',
        fill: d => dstype[d.dataset],
        fillOpacity: d => d.t == 'overhead' ? 1 : 0.6,
        // fill: d => d.t == 'overhead' ? dstype[d.dataset] : 'red',
        // fill: d => d.t == 'overhead' ? 'blue' : 'red',
        // sort: null,
        sort: {y: null, color: null, fy: {type: "x"}},
        // sort: d => ord.indexOf(d.dataset)
      }),
      Plot.axisFy({
        fontSize: '15px',
        label: null,
        anchor: 'left',
        dx: -17,
        tickFormat: (d, i, _) => algnames[d],
        lineHeight: 1.2,
      }),
      // Plot.tickX(data, {fy: 'type', x: 'aggregate', y: "dataset"}),
      Plot.tickX(data.filter(d => d.t == 'overhead'), {fy: 'type', x: 'aggregate', y: "dataset"}),
      Plot.text(data.filter(d => d.t == 'overhead'), {
        y: 'dataset', fy: 'type',
        x: 'aggregate',
        // text: d => d.val < baseline ? '<1ms' : `${formatMs(d.val)}`,
        text: d => `${formatBytes(d.aggregate)}`,
        fontSize: 9,
        textAnchor: 'start',
        fill: 'black',
        dx: 6,
      }),
      // Plot.text(data, {
      //   y: 'dataset', fy: 'type',
      //   x: baseline,
      //   textAnchor: 'start',
      //   dx: 3,
      //   fontWeight: 800,
      //   text: d => d.dataset,
      //   fill: 'white',
      // }),
      // Plot.text(data, {y: 'dataset', fy: 'type', text: (d) => (d.val * 100).toFixed(1), dx: -6, lineAnchor: "bottom"}),

      // Plot.text(data, {
      //   text: d => `${Math.floor(d.value / 1000)} ms`,
      //   y: "type",
      //   x: "val",
      //   textAnchor: "end",
      //   dx: -3,
      //   fill: "white"
      // }),
      // Plot.text(data, {x: 'val', y: 'type', text: 'asdf', textAnchor: 'end', dx: 5}),
      Plot.ruleX([0], {strokeWidth: 1.5}),
      // Plot.ruleX([baseline], {
      //   dx: -22,
      //   strokeWidth: 1.5
      // }),
      // Plot.ruleY([0]),
    ]
  })
}

const plotSizeBig = () => {
  const data = [
    ...datasets.map(dataset => ({
      dataset,
      type: 'dt',
      val: dt_stats[dataset].ins_content_len_utf8,
      aggregate: dt_stats[dataset].ins_content_len_utf8,
      t: 'lowerbound'
    })),
    ...datasets.map(dataset => ({
      dataset,
      type: 'dt',
      val: dt_stats[dataset].uncompressed_size - dt_stats[dataset].ins_content_len_utf8,
      t: 'overhead',
      aggregate: dt_stats[dataset].uncompressed_size
    })),

    ...datasets.map(dataset => ({
      dataset,
      type: 'automerge',
      val: dt_stats[dataset].ins_content_len_utf8,
      aggregate: dt_stats[dataset].ins_content_len_utf8,
      t: 'lowerbound'
    })),
    ...datasets.map(dataset => ({
      dataset,
      type: 'automerge',
      val: yjs_am_sizes[dataset].automergeUncompressed - dt_stats[dataset].ins_content_len_utf8,
      t: 'overhead',
      aggregate: yjs_am_sizes[dataset].automergeUncompressed
    })),
  ]

  // console.log(data)
  return plotSize(data, 4.3e6)
}

const plotSizeSmol = () => {
  const data = [
    ...datasets.map(dataset => ({
      dataset,
      type: 'dt',
      val: dt_stats[dataset].final_doc_len_utf8,
      aggregate: dt_stats[dataset].final_doc_len_utf8,
      t: 'lowerbound'
    })),
    ...datasets.map(dataset => ({
      dataset,
      type: 'dt',
      val: dt_stats[dataset].uncompressed_smol_size - dt_stats[dataset].final_doc_len_utf8,
      t: 'overhead',
      aggregate: dt_stats[dataset].uncompressed_smol_size
    })),

    ...datasets.map(dataset => ({
      dataset,
      type: 'yjs',
      val: dt_stats[dataset].final_doc_len_utf8,
      aggregate: dt_stats[dataset].final_doc_len_utf8,
      t: 'lowerbound'
    })),
    ...datasets.map(dataset => ({
      dataset,
      type: 'yjs',
      val: yjs_am_sizes[dataset].yjs - dt_stats[dataset].final_doc_len_utf8,
      t: 'overhead',
      aggregate: yjs_am_sizes[dataset].yjs
    })),
  ]

  // console.log(data)
  return plotSize(data, 3e6)
}



const plotFF = () => {
  const algnames = {
    ff_off: 'Opt disabled',
    ff_on: 'Opt enabled',
  }

  const data = [
    ...datasets.map(dataset => ({ dataset, type: 'ff_on', val: rawTimings.dt_merge_norm[dataset], })),

    //...datasets.map(dataset => ({ dataset, type: 'ff_on', val: rawTimings.dt_ff_on[dataset], })),
    ...datasets.map(dataset => ({ dataset, type: 'ff_off', val: rawTimings.dt_ff_off[dataset], })),
  ]

  // console.log(data)

  return Plot.plot({
    figure: false,
    document: window.document,
    // marginLeft: 130,
    marginLeft: 115,
    // marginRight: 60,
    // marginBottom: 40,
    width: 500,
    height: 220,
    style: {
      background: 'white',
      // 'background-color': 'green',
      // "font-size": "14px",
      'font-family': 'Helvetica Neue, Helvetica, Arial, sans-serif',
    },
    // fy: {
    //   // tickRotate: '-90',
    //   label: null,
    //   tickFormat: (d, i, _) => algnames[d],
    //   // axis: 'left',
    // },
    y: {
      // label: 'Algorithm',
      // label: null,
      // domain: data.map(d => d.dataset),
      axis: null,
      // tickFormat: 's',
      // inset: 0.1,

    },
    x: {
      label: 'Time taken to merge all events, in milliseconds. (Less is better)',
      fontSize: "20px",
      grid: true,
      domain: [0, 100],
      // type: 'linear',
      // nice: true,
      // type: 'log',
      axis: 'bottom',
      // tickSpacing: 50,
      // marginBottom: 40,
      // labelOffset: 40,
      // tickFormat: '1s',
      // tickSize: 4,
      // tickSpacing: 40,
      // strokeOpacity: 1,
      // tickFormat: (a, b, c) => formatMs(a),
    },
    color: {
      scheme: "Dark2"
    },
    marks: [
      Plot.gridX({
        strokeWidth: 0.5,
        strokeOpacity: 0.15,
        tickSpacing: 45,
      }),
      Plot.axisY({
        // textAnchor: 'start',
        // fill: 'white',
        // dx: 10,
        // ticks: null,
        label: null,
        fontSize: 8
      }),
      // Plot.frame({
      //   fy: 'dt',
      //   // stroke: null,
      //   fill: 'green',
      //   opacity: 0.1,
      // }),
      Plot.barX(data, {
        y: 'dataset',
        fy: 'type',
        x1: 0,
        x2: d => Math.max(d.val, 0),
        // fill: 'type',
        fill: d => dstype[d.dataset],
        // sort: null,
        sort: {y: null, color: null, fy: {type: "x"}},
        // sort: d => ord.indexOf(d.dataset)
      }),
      Plot.axisFy({
        fontSize: '15px',
        label: null,
        anchor: 'left',
        dx: -17,
        tickFormat: (d, i, _) => algnames[d],
        lineHeight: 1.2,
      }),
      // Plot.ruleX([1000/60], {stroke: '#800000', strokeOpacity: 0.5}),
      Plot.tickX(data, {fy: 'type', x: d => Math.max(d.val, 0), y: "dataset"}),
      Plot.text(data, {
        y: 'dataset', fy: 'type',
        x: d => Math.max(d.val, 0),
        // text: d => d.val < 0 ? '<1ms' : `${formatMs(d.val)}`,
        text: d => `${formatMs(d.val)}`,
        fontSize: 9,
        textAnchor: 'start',
        fill: 'black',
        dx: 6,
      }),
      // Plot.text(data, {
      //   y: 'dataset', fy: 'type',
      //   x: 0,
      //   textAnchor: 'start',
      //   dx: 3,
      //   fontWeight: 800,
      //   text: d => d.dataset,
      //   fill: 'white',
      // }),
      // Plot.text(data, {y: 'dataset', fy: 'type', text: (d) => (d.val * 100).toFixed(1), dx: -6, lineAnchor: "bottom"}),

      // Plot.text(data, {
      //   text: d => `${Math.floor(d.value / 1000)} ms`,
      //   y: "type",
      //   x: "val",
      //   textAnchor: "end",
      //   dx: -3,
      //   fill: "white"
      // }),
      // Plot.text(data, {x: 'val', y: 'type', text: 'asdf', textAnchor: 'end', dx: 5}),
      Plot.ruleX([0], {strokeWidth: 1.5}),
      // Plot.ruleX([baseline], {
      //   dx: -22,
      //   strokeWidth: 1.5
      // }),
      // Plot.ruleY([0]),
    ]
  })
}



savePlot(plotTimes(), "timings.svg")
savePlot(plotMemusage(), "memusage.svg")
savePlot(plotSizeBig(), 'filesize_full.svg')
savePlot(plotSizeSmol(), 'filesize_smol.svg')
savePlot(plotFF(), "ff.svg")