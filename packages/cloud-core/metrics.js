/* eslint global-require:0 */
const {env: {NODE_ENV, SIGNALFX_TOKEN}, pid} = process
const os = require('os')
const signalfx = require('signalfx')

let signalfxClient = null

const MetricTypes = {
  Gauge: 'gauges',
  Counter: 'counters',
  CumulativeCounter: 'cumulative_counters',
}
const shouldReport = NODE_ENV && NODE_ENV !== 'development'


const Metrics = {

  MetricTypes,

  startCapturing(name) {
    if (!shouldReport) { return }
    signalfxClient = new signalfx.Ingest(SIGNALFX_TOKEN, {
      dimensions: {
        name,
        host: os.hostname(),
        pid: pid.toString(),
        env: NODE_ENV,
      },
    })
  },

  reportError() {
  },

  reportMetric({name, value, type, dimensions = {}} = {}) {
    if (!signalfxClient || !shouldReport) { return }
    if (!name) {
      throw new Error('Metrics.reportMetric requires a metric.name')
    }
    if (value == null) {
      throw new Error('Metrics.reportMetric requires a metric.value')
    }
    if (!type) {
      throw new Error('Metrics.reportMetric requires a metric.type from Metrics.MetricTypes')
    }
    const metric = {metric: name, value, timestamp: Date.now(), dimensions}
    signalfxClient.send({[type]: [metric]})
  },
}

module.exports = Metrics
