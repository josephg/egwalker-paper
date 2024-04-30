// UNUSED

// Read in a patch file and check that the patches all apply correctly.
const fs = require('fs')
const assert = require('assert')
const zlib = require('zlib')
const Y = require('yjs')
const v8 = require('v8')

const filename = process.argv[2]

if (filename == null) {
  console.error(`Usage: $ ${process.argv.join(' ')} file.json[.gz]`)
  process.exit(1)
}


const {
  startContent,
  endContent,
  txns
} = JSON.parse(
  filename.endsWith('.gz')
  ? zlib.gunzipSync(fs.readFileSync(filename))
  : fs.readFileSync(filename, 'utf-8')
)

// console.log('snapshot', v8.writeHeapSnapshot())
console.log(v8.getHeapStatistics())
console.log('heap', process.memoryUsage().heapUsed)

const run = () => {
  gc()
  const startMemory = v8.getHeapStatistics().used_heap_size
  const state = new Y.Doc()

  for (let i = 0; i < txns.length; i++) {
    // if (i > 20000) break
    // if (i % 10000 == 0) console.log(i)
    const {patches} = txns[i]

    state.transact(txn => {
      const text = txn.doc.getText()
      for (const [pos, delHere, insContent] of patches) {
        // console.log(pos, delHere, insContent)
        if (delHere > 0) text.delete(pos, delHere)
        if (insContent !== '') text.insert(pos, insContent)
        // state = automerge.change(state, doc => {
          //   if (delHere > 0) doc.text.deleteAt(pos, delHere)
          //   if (insContent !== '') doc.text.insertAt(pos, insContent)
          // })
      }
    })
  }
  gc()
  console.log('RAM used:', v8.getHeapStatistics().used_heap_size - startMemory)
  console.log(state.getText().length)
  console.log(txns.length)
  const data = Y.encodeStateAsUpdateV2(state)
  console.log(`encodes to ${data.byteLength} bytes (${data.byteLength - endContent.length} overhead)`)
}

const run2 = () => {
  // const state = new Doc()
  const state = new Y.Doc()
  const text = state.getText()

  for (let i = 0; i < 5000000; i++) {
    text.insert(0, 'x')
  }
  assert.strictEqual(text.length, 5000000)
}

console.log('applying', txns.length, 'txns...')

for (let i = 0; i < 10; i++) {
  // Warmup
  run()
}
console.time('apply')
run()
console.timeEnd('apply')
// gc()
console.log(v8.getHeapStatistics())
console.log('heap', process.memoryUsage().heapUsed)

// console.log('snapshot', v8.writeHeapSnapshot())
// assert.strictEqual(state.text.toSpans().join(''), endContent)

// assert.strictEqual(state.getText().toJSON(), endContent)