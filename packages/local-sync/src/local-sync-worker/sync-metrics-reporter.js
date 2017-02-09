const {N1CloudAPI, NylasAPIRequest, AccountStore} = require('nylas-exports');
const os = require('os');

class SyncMetricsReporter {
  async collectCPUUsage() {
    return new Promise((resolve) => {
      const startUsage = process.cpuUsage();
      const sampleDuration = 400;
      setTimeout(() => {
        const {user, system} = process.cpuUsage(startUsage);
        const fractionToPrecent = 100.0;
        resolve(Math.round((user + system) / (sampleDuration * 1000.0) * fractionToPrecent));
      }, sampleDuration);
    });
  }

  async reportEvent(info) {
    if (!info.emailAddress) {
      throw new Error("You must include email_address");
    }
    const logger = global.Logger.child({accountEmail: info.emailAddress})
    const {workingSetSize, privateBytes, sharedBytes} = process.getProcessMemoryInfo();
    const percentCPU = await this.collectCPUUsage();

    info.hostname = os.hostname();
    info.cpus = os.cpus().length;
    info.arch = os.arch();
    info.platform = process.platform;
    info.version = NylasEnv.getVersion();
    info.processWorkingSetSize = workingSetSize;
    info.processPrivateBytes = privateBytes;
    info.processSharedBytes = sharedBytes;
    info.processPercentCPU = percentCPU;

    const req = new NylasAPIRequest({
      api: N1CloudAPI,
      options: {
        path: `/ingest-metrics`,
        method: 'POST',
        body: info,
        accountId: AccountStore.accountForEmail(info.emailAddress).id,
      },
    });
    req.run()
    .then(() => {
      logger.log(info, "Metrics Collector: Submitted.", info);
    })
    .catch(() => {
      logger.warn("Metrics Collector: Submission Failed.", info);
    })
  }
}

module.exports = new SyncMetricsReporter();
