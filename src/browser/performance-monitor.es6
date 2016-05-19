import Utils from '../../src/flux/models/utils'
const BUFFER_SIZE = 100;

/**
 * A benchmarking system to keep track of start and end times for various
 * event types.
 */
export default class PerformanceMonitor {
  constructor() {
    this._doneRuns = {}
    this._pendingRuns = {}
  }

  start(key) {
    if (!this._pendingRuns[key]) {
      this._pendingRuns[key] = [Date.now()]
    }
  }

  /**
   * This will add split points in an ongoing run (or do nothing if no run
   * has started). Useful for fine-grained debugging of long timers.
   */
  split(key) {
    if (!this._pendingRuns[key]) { return {} }
    this._pendingRuns[key].push(Date.now())
    return {
      split: this.calcSplit(this._pendingRuns[key]),
      total: this.calcTotal(this._pendingRuns[key]),
    }
  }

  stop(key) {
    if (!this._pendingRuns[key]) { return 0 }
    if (!this._doneRuns[key]) { this._doneRuns[key] = [] }
    this._pendingRuns[key].push(Date.now());
    const total = this.calcTotal(this._pendingRuns[key])
    this._doneRuns[key].push(this._pendingRuns[key])
    if (this._doneRuns[key].length > BUFFER_SIZE) {
      this._doneRuns[key].shift()
    }
    delete this._pendingRuns[key]
    return total
  }

  calcSplit(curRun) {
    return curRun[curRun.length - 1] - curRun[curRun.length - 2]
  }

  calcTotal(curRun) {
    return curRun[curRun.length - 1] - curRun[0]
  }

  calcMean(key) {
    return Utils.mean(this.totals(key))
  }

  calcStdev(key) {
    return Utils.stdev(this.totals(key))
  }

  totals(key) {
    return this._doneRuns[key].map(this.calcTotal)
  }

  runsFor(key) {
    return this._doneRuns[key]
  }

  clear(key) {
    delete this._doneRuns[key]
  }

}
