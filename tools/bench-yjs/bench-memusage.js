// This file gets memory usage statistics for yjs loading the different
// datasets.
//
// Note this is very imprecise, because V8 is extremely complex.

const fs = require('fs')
const Y = require('yjs')
const v8 = require('v8')
const {bench} = require('smolbench')

// Needs --expose-gc.
gc()

const DATASETS = ["S1", "S2", "S3", "C1", "C2", "A1", "A2"]
// const DATASETS = ["S1"]

console.log(v8.getHeapStatistics())
console.log('heap', process.memoryUsage().heapUsed)

// const sleep = t => new Promise(res => setTimeout(res, t))

const yjsData = DATASETS.map(name => ({
  name,
  data: fs.readFileSync(`../../datasets/${name}.yjs`),
}))

// Run the "benchmark" a bunch of times to warm up V8.
for (const {name, data} of yjsData) {
  console.log('warmup', name)

  bench({name: null, samples: 10}, () => {
    let doc = new Y.Doc()
    Y.applyUpdateV2(doc, data)
  })
}

gc()
// console.log(v8.getHeapStatistics())
// console.log('heap', process.memoryUsage().heapUsed)

const memusage = {}

for (const {name, data} of yjsData) {
  console.log(name, '...')
  gc()
  v8.gc

  const startMemory = v8.getHeapStatistics().used_heap_size

  let doc = new Y.Doc()
  Y.applyUpdateV2(doc, data)

  const ramUsed = v8.getHeapStatistics().used_heap_size - startMemory
  console.log(name, 'RAM used:', ramUsed)
  // console.log(doc.getText().length)
  Y.encodeStateAsUpdateV2(doc) // To make sure it doesn't get GCed.

  // We can't differentiate these with javascript. We'll assume they're the same - but
  // its basically impossible to get good values here.
  memusage[name] = {steady_state: ramUsed, peak: ramUsed}
}

console.log(memusage)
fs.writeFileSync('../../results/yjs_memusage.json', JSON.stringify(memusage, null, 2))


// gc()
// console.log(v8.getHeapStatistics())
// console.log('heap', process.memoryUsage().heapUsed)
