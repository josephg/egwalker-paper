import * as Plot from '@observablehq/plot'
import * as d3 from 'd3'
import fs from 'fs'
import {JSDOM} from "jsdom";

const {window} = new JSDOM("")


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

const algnames = {
  dt: "Eg-walker",
  ot: "OT",
  dtcrdt: "Ref CRDT",
  yjs: "Yjs",
  automerge: "Automerge"
}

const dstype = { "S1": 'seq', "S2": 'seq', "A1": 'async', "A2": 'async', "C1": 'conc', "C2": 'conc', "S3": 'seq', }

const formatMs = (ms) => (
  ms < 1000 ? `${roundAuto(ms)} ms`
      : ms < 60*1000 ? `${roundAuto(ms / 1000)} sec`
      : `${roundAuto(ms / (60 * 1000))} min`
)

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
  const data = [
    ...datasets.map(name => ({ dataset: name, type: 'dt', val: rawTimings.dt_merge_norm[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'ot', val: rawTimings.ot[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'dtcrdt', val: rawTimings['dt-crdt_process_remote_edits'][name], })),
    ...datasets.map(name => ({ dataset: name, type: 'automerge', val: rawTimings.automerge_remote[name], })),
    ...datasets.map(name => ({ dataset: name, type: 'yjs', val: rawTimings.yjs_remote[name], })),
  ]

  console.log(data)
  // figure: false,
  // document: window.document,

  const baseline = 0.8

  return Plot.plot({
    figure: false,
    document: window.document,
    // marginLeft: 130,
    marginLeft: 85,
    marginRight: 60,
    // marginBottom: 40,
    width: 500,
    height: 400,
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
      // inset: 1,
      
    },
    x: {
      label: 'Merge time taken (milliseconds) (less is better)',
      grid: true,
      domain: [baseline, 37000000],
      // type: 'linear',
      // nice: true,
      type: 'log',
      axis: 'bottom',
      // labelOffset: 40,
      // tickFormat: '1s',
      // tickSize: 4,
      tickSpacing: 50,
      // strokeOpacity: 1,
      // tickFormat: (a, b, c) => `${formatMs(a)}`,
    },
    color: {
      scheme: "Dark2"
    },
    marks: [
      // Plot.axisY({
      //   textAnchor: 'start',
      //   fill: 'white',
      //   dx: 10,
      // }),
      // Plot.frame(),
      Plot.barX(data, {
        y: 'dataset',
        fy: 'type',
        x1: baseline,
        x2: 'val',
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
        tickFormat: (d, i, _) => algnames[d],
      }),
      Plot.ruleX([60], {stroke: '#800000', strokeOpacity: 0.5}),
      Plot.tickX(data, {fy: 'type', x: "val", y: "dataset"}),
      Plot.text(data, {
        y: 'dataset', fy: 'type',
        x: 'val',
        text: d => `${formatMs(d.val)}`,
        textAnchor: 'start',
        fill: 'black',
        dx: 6,
      }),
      Plot.text(data, {
        y: 'dataset', fy: 'type',
        x: baseline,
        textAnchor: 'start',
        dx: 3,
        fontWeight: 800,
        text: d => d.dataset,
        fill: 'white',
      }),
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
      Plot.ruleX([baseline]),
      // Plot.ruleY([0]),
    ]
  })
}

savePlot(plotTimes(), "test.svg")
// const plot = Plot.rectY( {length: 10000}, Plot.binX({y: "count"}, {x: Math.random}) )
//   .plot({document: window.document})
// savePlot(plot, "blah.svg")