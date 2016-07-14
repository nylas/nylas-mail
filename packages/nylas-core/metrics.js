const {NODE_ENV} = process.env

class Metrics {
  constructor() {
    this.newrelic = null
    this.shouldReport = NODE_ENV && NODE_ENV !== 'development'
  }

  startCapturing() {
    if (this.shouldReport) {
      this.newrelic = require('newrelic')
    }
  }

  reportError(error) {
    if (this.newrelic && this.shouldReport) {
      this.newrelic.noticeError(error)
    }
  }

  reportMetric() {

  }
}

module.exports = new Metrics()
