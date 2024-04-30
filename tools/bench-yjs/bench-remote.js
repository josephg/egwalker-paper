const fs = require('fs')
const Y = require('yjs')
const {bench, saveReportsSync, reportTable} = require('smolbench')

// const DATASETS = ["automerge-paper", "seph-blog1", "clownschool", "friendsforever", "node_nodecc", 'egwalker']
const DATASETS = ["S1", "S2", "S3", "C1", "C2", "A1", "A2"]


for (const d of DATASETS) {
// for (const d of ['seph-blog1']) {
  const data = fs.readFileSync(`../../datasets/${d}.yjs`)
  bench(`yjs/remote/${d}`, () => {
    let doc = new Y.Doc()
    Y.applyUpdateV2(doc, data)
  })
}

saveReportsSync('../paper-benchmarks/results/js.json')
reportTable()

// for (const d of DATASETS) {
//   console.log(d)
//   const data = fs.readFileSync(`${d}.yjs`)
//   // let snapshot = Y.decodeSnapshotV2(data)


//   let doc = new Y.Doc()
//   Y.applyUpdateV2(doc, data)
//   let text = doc.getText("text")
//   console.log('length', text.length)


//   // Warmup
//   for (let i = 0; i < 10; i++) {
//     let doc = new Y.Doc()
//     Y.applyUpdateV2(doc, data)
//   }


//   const n = 10
//   let start = perf.now()
//   // console.time(d)
//   for (let i = 0; i < n; i++) {
//     let doc = new Y.Doc()
//     Y.applyUpdateV2(doc, data)
//   }
//   let end = perf.now()
//   console.log('Time:', (end - start) / n, 'ms')
//   // console.timeEnd(d)

// }
