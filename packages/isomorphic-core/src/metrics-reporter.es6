import os from 'os'
import {isClientEnv, isCloudEnv} from './env-helpers'

/**
 * NOTE: This is the Honeycomb performance metrics reporting for the Nylas
 * Mail Client. It is NOT the logging data for cloud plugins. This is
 * accessed via the /ingest-metrics endpoint of the cloud api. this can
 * also be used from the cloud environment to report metrics to honeycomb,
 * which is different from sending the logs to honeycomb
 *
 * Each AWS box automatically sends all log data to Honeycomb via
 * honeytail. You can find the config by ssh-ing to a production cloud box
 * and looking at /etc/sv/honeytail/run
 */
class MetricsReporter {

  constructor() {
    this._honey = null
    this._baseReportingData = {
      hostname: os.hostname(),
      cpus: os.cpus().length,
      arch: os.arch(),
      platform: process.platform,
      version: isClientEnv() ? NylasEnv.getVersion() : undefined,
    }

    if (isCloudEnv()) {
      const LibHoney = require('libhoney').default // eslint-disable-line

      this._honey = new LibHoney({
        writeKey: process.env.HONEY_WRITE_KEY,
        dataset: process.env.HONEY_DATASET,
      })
    }
  }

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

  sendToHoneycomb(data) {
    if (!this._honey) {
      throw new Error('Metrics Reporter: Honeycomb is not available in this environment')
    }
    this._honey.sendNow(data);
  }

  async reportEvent(data) {
    if (!data.nylasId) {
      throw new Error("Metrics Reporter: You must include an nylasId");
    }
    const {accountId: id, emailAddress} = data
    const logger = global.Logger ? global.Logger.forAccount({id, emailAddress}) : console;
    const {workingSetSize, privateBytes, sharedBytes} = process.getProcessMemoryInfo();

    const dataToReport = Object.assign({}, this._baseReportingData, data, {
      processWorkingSetSize: workingSetSize,
      processPrivateBytes: privateBytes,
      processSharedBytes: sharedBytes,
    })

    try {
      if (!isClientEnv()) {
        this.sendToHoneycomb(dataToReport)
        return
      }
      if (NylasEnv.inDevMode()) { return }

      const {IdentityStore, N1CloudAPI, NylasAPIRequest} = require('nylas-exports') // eslint-disable-line
      if (!IdentityStore.identity()) {
        throw new Error("Metrics Reporter: Identity must be available");
      }
      if (!dataToReport.accountId) {
        throw new Error("Metrics Reporter: You must include an accountId");
      }

      const req = new NylasAPIRequest({
        api: N1CloudAPI,
        options: {
          path: `/ingest-metrics`,
          method: 'POST',
          body: dataToReport,
          accountId: dataToReport.accountId,
        },
      });
      await req.run()
      logger.log("Metrics Reporter: Submitted.", dataToReport);
    } catch (err) {
      logger.warn("Metrics Reporter: Submission Failed.", {error: err, ...dataToReport});
    }
  }
}

export default new MetricsReporter();
