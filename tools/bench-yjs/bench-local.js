const fs = require('fs')
// const assert = require('assert')
const zlib = require('zlib')
const Y = require('yjs')
// const v8 = require('v8')
const {bench, saveReportsSync, benchFancy, reportTable} = require('smolbench')


const DATASETS = ['egwalker']
// const DATASETS = ["automerge-paper", "seph-blog1", "clownschool_flat", "friendsforever_flat", 'egwalker']


for (const d of DATASETS) {
  const data = JSON.parse(zlib.gunzipSync(
    fs.readFileSync(`../../editing-traces/sequential_traces/${d}.json.gz`)
  ))
  let {startContent, txns} = data
  // console.log(txns.length)

  bench(`yjs/local/${d}`, () => {
    let state = new Y.Doc()

    for (let i = 0; i < txns.length; i++) {
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
  })

  // This is crazy slow.
  // benchFancy(`yjs/local_one_txn/${d}`, (b) => {
  //   let state = new Y.Doc()
  //   state.transact(txn => {
  //     const text = txn.doc.getText()

  //     b(() => {
  //       for (let i = 0; i < txns.length; i++) {
  //         const {patches} = txns[i]

  //         for (const [pos, delHere, insContent] of patches) {
  //           // console.log(pos, delHere, insContent)
  //           if (delHere > 0) text.delete(pos, delHere)
  //           if (insContent !== '') text.insert(pos, insContent)
  //         }
  //       }
  //     })
  //   })
  // })
}

saveReportsSync('../paper-benchmarks/results/js.json')
reportTable()
