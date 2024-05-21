// This file merges a bunch of bits of data from criterion and other sources to create stuff in results.
// Eg, importantly results/timings.json.

const fs = require('fs')
const assert = require('assert/strict')
// const zlib = require('zlib')

// const datasets = ['automerge-paper', 'seph-blog1', 'clownschool', 'friendsforever', 'git-makefile', 'node_nodecc', 'clownschool_flat', 'friendsforever_flat', 'egwalker',
//   "automerge-paperx3", "seph-blog1x3", "node_nodeccx1", "git-makefilex2", "friendsforeverx25", "clownschoolx25", "egwalkerx1"
// ]
const datasets = ["S1", "S2", "S3", "C1", "C2", "A1", "A2"]
// const datasetsAmYjs = ['automerge-paper', 'seph-blog1', 'clownschool', 'friendsforever', 'node_nodecc', 'egwalker']

const tests = [
  // 'dt/merge', // DEPRECATED.
  'dt/merge_norm',
  // 'dt/ff_on',
  'dt/ff_off',
  'dt/opt_load',

  // 'dt/local',
  // 'dt/local_rle',
  'dt-crdt/process_remote_edits', // from run_on_old
  // 'dt-crdt/local',

  // 'automerge/local',
  'automerge/remote',
  // 'cola/local',
  // 'cola-nocursor/local',

  'ot',
]

const lerp = (a, b, x) => (a * (1-x) + b * x)

const percentile = (samples, at) => {
  assert(at >= 0)
  assert(at <= 1)

  // at between 0 and 1.
  samples.sort((a, b) => a < b)

  // from https://docs.rs/stats-cli/latest/src/inc_stats/lib.rs.html#498-500
  const pIdx = (samples.length - 1) * at
  const lowIdx = Math.floor(pIdx)
  const highIdx = Math.ceil(pIdx)
  // const low = ordering.order_index(lowIdx);
  // const high = ordering.order_index(highIdx);
  const weight = pIdx - lowIdx

  // console.log(samples)
  // console.log(pIdx, lowIdx, highIdx, weight)
  // const p = at * (samples.length + 1)
  // if (Number.isInteger(p)
  return lerp(samples[lowIdx], samples[highIdx], weight)
}

const stddev = (samples) => {
  assert(samples.length >= 1)

  // samples.sort((a, b) => a < b)
  const n = samples.length
  const mean = samples.reduce((a, b) => a + b) / n
  const variance = samples
  .map(s => s - mean) // move to the mean
  .map(v => v * v)
  .reduce((a, b) => a + b) / n // mean of variance
  return Math.sqrt(variance)
}

// console.log(lerp(1, 2, 0.5))
// console.log(percentile([1,2,2,8,10], 0.4))

// Samples is a list of sample times. For criterion this comes from dividing times by iters.
const getStats = samples => {
  samples.sort((a, b) => a < b)
  const n = samples.length

  const mean = samples.reduce((a, b) => a + b) / n
  const p10 = percentile(samples, 0.10)
  const p25 = percentile(samples, 0.25)
  const p75 = percentile(samples, 0.75)
  const p90 = percentile(samples, 0.90)

  return {
    mean, p10, p90, stddev: stddev(samples)
  }
}

function emitSpeeds() {
  const speeds = {}

  for (const test of tests) {
    let s = speeds[test.replace(/\//g, '_')] = {}
    for (const d of datasets) {
      try {
        const {iters, times} = JSON.parse(fs.readFileSync(`target/criterion/${test}/${d}/base/sample.json`, 'utf8'))
        assert.equal(iters.length, times.length)
        // console.log(iters.length, times.length)
        // Convert from ns to ms.
        const timesMs = times.map((x, i) => x / iters[i] * 1e-6)
        const stats = getStats(timesMs)
        // console.log(d, stats.stddev)

        if ((stats.stddev / stats.mean) > 0.01) {
          console.log('stddev more than 1%', test, d, 'it is', stats.stddev / stats.mean)
        }

        // let project = test == 'automerge/remote' ? 'automerge-converter' : 'diamond-types'
        // const estimates = JSON.parse(fs.readFileSync(`target/criterion/${test}/${d}/base/estimates.json`, 'utf8'))
        // console.log(estimates.mean.point_estimate * 1e-6)
        // console.log(d, estimates.std_dev.point_estimate * 1e-6)

        // console.log('t', test, 'd', d, data.mean.point_estimate)

        // speeds[`${test.replace(/\//g, '_')}_${d}`] = data.mean.point_estimate
        // s[d] = estimates.mean.point_estimate / 1e6
        s[d] = stats
      } catch (e) {
        if (e.code == 'ENOENT') {
          console.warn('Warning: No data for', test, d)
        } else throw e
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
      const samples = jsData[k].sampleTimes
      const stats = getStats(samples)
      // const mean = jsData[k].meanTime
      // console.log(d, mean)

      // console.log(d, stats)


      if ((stats.stddev / stats.mean) > 0.01) {
        console.log('stddev more than 1%', d, 'it is', stats.stddev / stats.mean)
      }

      yjs[d] = stats
    }
  }

  fs.writeFileSync('results/timings.json', JSON.stringify(speeds, null, 2))
  // console.log(JSON.stringify(speeds, null, 2))
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
    // console.log(d)

    sizes[d] = {
      yjs: fs.statSync(`datasets/${d}.yjs`).size,
      automergeUncompressed: fs.statSync(`datasets/${d}-uncompressed.am`).size
    }

    // console.log('yjs', fs.statSync(`datasets/${d}.yjs`).size)
    // console.log('am-uncomp', fs.statSync(`datasets/${d}-uncompressed.am`).size)
  }

  fs.writeFileSync('results/yjs_am_sizes.json', JSON.stringify(sizes, null, 2))
  // console.log(sizes)
}

emitSpeeds()
emitFilesizes()


