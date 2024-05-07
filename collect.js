// This file merges a bunch of bits of data from criterion and other sources to create stuff in results.
// Eg, importantly results/timings.json.

const fs = require('fs')
// const zlib = require('zlib')

// const datasets = ['automerge-paper', 'seph-blog1', 'clownschool', 'friendsforever', 'git-makefile', 'node_nodecc', 'clownschool_flat', 'friendsforever_flat', 'egwalker',
//   "automerge-paperx3", "seph-blog1x3", "node_nodeccx1", "git-makefilex2", "friendsforeverx25", "clownschoolx25", "egwalkerx1"
// ]
const datasets = ["S1", "S2", "S3", "C1", "C2", "A1", "A2"]
// const datasetsAmYjs = ['automerge-paper', 'seph-blog1', 'clownschool', 'friendsforever', 'node_nodecc', 'egwalker']
const datasetsAmYjs = datasets
const tests = {
  // 'automerge-converter': ['automerge/remote'],
  'diamond-types': [
    // 'dt/merge', // DEPRECATED.
    'dt/merge_norm',
    'dt/ff_on',
    'dt/ff_off',
    'dt/opt_load',

    // 'dt/local',
    // 'dt/local_rle',
    'dt-crdt/process_remote_edits', // from run_on_old
    // 'dt-crdt/local',
  ],
  'paper-benchmarks': [
    'automerge/local',
    'automerge/remote',
    'cola/local',
    'cola-nocursor/local',
    // 'yrs/local',
  ],
  'ot-bench': [
    'ot',
  ],
}

function emitSpeeds() {
  const speeds = {}

  for (const project in tests) {
    for (const test of tests[project]) {
      let s = speeds[test.replace(/\//g, '_')] = {}
      for (const d of datasets) {
        try {
          // let project = test == 'automerge/remote' ? 'automerge-converter' : 'diamond-types'
          const data = JSON.parse(fs.readFileSync(`tools/${project}/target/criterion/${test}/${d}/base/estimates.json`, 'utf8'))

          console.log('t', test, 'd', d, data.mean.point_estimate)

          // speeds[`${test.replace(/\//g, '_')}_${d}`] = data.mean.point_estimate
          s[d] = data.mean.point_estimate / 1e6
        } catch (e) {
          if (e.code == 'ENOENT') {
            console.warn('Warning: No data for', test, d)
          } else throw e
        }
      }
    }
  }

  // for (const algorithm of ['automerge', 'cola', 'cola-nocursor']) {
  //   // let s = speeds[test.replace(/\//g, '_')] = {}
  //   let s = speeds[`${algorithm}_local`] = {}
  //   for (const d of datasets) {
  //     try {
  //       let project = 'crdt-benchmarks/paper-benchmarks'
  //       const data = JSON.parse(fs.readFileSync(`${project}/target/criterion/local_${d}/${algorithm}/base/estimates.json`, 'utf8'))

  //       // console.log('t', test, 'd', d, data.mean.point_estimate)

  //       // speeds[`${test.replace(/\//g, '_')}_${d}`] = data.mean.point_estimate
  //       s[d] = data.mean.point_estimate / 1e6
  //     } catch (e) {
  //       if (e.code == 'ENOENT') {
  //         console.warn('Warning: No data for', d)
  //       } else throw e
  //     }
  //   }
  // }


  // And pull data for yjs.
  const jsData = JSON.parse(fs.readFileSync('results/js.json', 'utf-8'))
  const yjs = speeds.yjs_remote = {}
  for (const d of datasets) {
    const k = `yjs/remote/${d}`
    if (jsData[k] == null) {
      console.warn('Missing js data for key ' + k)
    } else {
      const mean = jsData[k].meanTime
      // console.log(d, mean)
      yjs[d] = mean
    }
  }

  fs.writeFileSync('results/timings.json', JSON.stringify(speeds, null, 2))
  console.log(JSON.stringify(speeds, null, 2))
}

// function emitTestDataStats() {
//   const numPatches = {}

//   for (const d of datasets) {
//     try {
//       const data = JSON.parse(
//         zlib.gunzipSync(
//           fs.readFileSync(`../diamond-types/benchmark_data/${d}.json.gz`)
//         )
//       )

//       const p = data.txns.map(t => t.patches.length).reduce((a, b) => a + b, 0)
//       // const p = data.txns.length
//       numPatches[d] = p
//     } catch (e) {
//       if (e.code == 'ENOENT') {
//         console.warn('Warning: No data for', d)
//       } else throw e
//     }
//   }

//   fs.writeFileSync('results/numpatches.json', JSON.stringify(numPatches, null, 2))
//   console.log(JSON.stringify(numPatches, null, 2))
// }

// // This is whory.
// function emitDTFileSizes() {
//   const posstats = fs.readFileSync('raw_posstats.txt', 'utf8').split('\n')

//   const match = regex => (
//     posstats.map(s => regex.exec(s))
//       .filter(s => s != null)
//       .map(m => m[1])
//   )
//   const matchN = regex => (
//     match(regex).map(n => +n)
//   )

//   // const files = posstats.filter(s => s.match(/Loaded testing data from (.*)/))
//   const names = match(/Loaded testing data from ([a-z_-]*)/)
//     .map(n => n == 'seph-blog' ? 'seph-blog1' : n)
//   console.log(names)

//   const finalSizes = matchN(/Total length (.*)/)
//   console.log('finalSizes', finalSizes)

//   const insText = matchN(/Inserted text length \(uncompressed\) (.*)/)
//   console.log('instext', insText)

//   const compressLen = matchN(/Compressed .* bytes in the file to (.*)/)
//   console.log('compressLen', compressLen)

//   const endContentLen = matchN(/End content length \(uncompressed\) (.*)/)
//   console.log(endContentLen)

//   const patchesLen = matchN(/Patches length (.*)/)
//   const docLen = matchN(/Resulting document size (.*?) characters/)

//   const amSize = names.map(n => datasetsAmYjs.includes(n) ? fs.statSync(`benchmark_data/${n}.am`).size : 0)
//   const amSizeUncompressed = names.map(n => datasetsAmYjs.includes(n) ? fs.statSync(`benchmark_data/${n}-uncompressed.am`).size : 0)

//   const yjsSize = names.map(n => datasetsAmYjs.includes(n) ? fs.statSync(`benchmark_data/${n}.yjs`).size : 0)

//   const result = {}

//   for (const n of names) {
//     result[n] = {
//       size: finalSizes.shift(),
//       smolSize: finalSizes.shift(),
//       uncompressedSize: finalSizes.shift(),
//       uncompressedSmolSize: finalSizes.shift(),

//       amSize: amSize.shift(),
//       amSizeUncompressed: amSizeUncompressed.shift(),
//       yjsSize: yjsSize.shift(),

//       insLen: insText.shift(),

//       endContentLen: endContentLen.shift(),
//       patchesLen: patchesLen.shift(),
//       smolPatchesLen: patchesLen.shift(),
//       // smolPatchesLenUncompressed: patchesLen.shift(),

//       normalTextCompressed: compressLen.shift(),
//       smolTextCompressed: compressLen.shift(),

//       docLen: docLen.shift(),
//     }
//     // This stuff should be the same size for all documents.
//     insText.shift()
//     endContentLen.shift()
//     patchesLen.shift()
//     patchesLen.shift()
//   }

//   if (finalSizes.length || insText.length || compressLen.length || endContentLen.length || patchesLen.length) {
//     console.error("Data:", names, finalSizes, 'insText', insText, 'compressLen', compressLen, 'endcontentlen', endContentLen, 'patchlen', patchesLen)
//     throw Error('Did not use all data')
//   }

//   fs.writeFileSync('results/filesizes.json', JSON.stringify(result, null, 2))
//   console.log(JSON.stringify(result, null, 2))
// }


// Emit the filesizes for yjs and automerge.
function emitFilesizes() {
  const sizes = {}

  for (const d of datasets) {
    console.log(d)

    sizes[d] = {
      yjs: fs.statSync(`datasets/${d}.yjs`).size,
      automergeUncompressed: fs.statSync(`datasets/${d}-uncompressed.am`).size
    }

    // console.log('yjs', fs.statSync(`datasets/${d}.yjs`).size)
    // console.log('am-uncomp', fs.statSync(`datasets/${d}-uncompressed.am`).size)
  }

  fs.writeFileSync('results/yjs_am_sizes.json', JSON.stringify(sizes, null, 2))
  console.log(sizes)
}

emitSpeeds()
emitFilesizes()


// emitTestDataStats()
// emitDTFileSizes()
