/**
 * NOTE: Metrics collection is disabled. Implement these methods to send
 * sync performance data to a service like Honeycomb.
 */
class MetricsReporter {

  async collectCPUUsage() {
    return Promise.resolve();
  }

  async reportEvent(data) { //eslint-disable-line
    // noop
  }
}

export default new MetricsReporter();
