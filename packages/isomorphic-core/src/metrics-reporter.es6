import os from 'os'
import {isClientEnv, isCloudEnv} from './env-helpers'

class MetricsReporter {

  constructor() {
    this._honey = null

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

  sendToHoneycomb(info) {
    if (!this._honey) {
      throw new Error('Metrics Reporter: Honeycomb is not available in this environment')
    }
    this._honey.sendNow(info);
  }

  async reportEvent(info) {
    if (!info.nylasId) {
      throw new Error("Metrics Reporter: You must include an nylasId");
    }
    const logger = global.Logger ? global.Logger.child({accountEmail: info.emailAddress}) : console;
    const {workingSetSize, privateBytes, sharedBytes} = process.getProcessMemoryInfo();

    info.hostname = os.hostname();
    info.cpus = os.cpus().length;
    info.arch = os.arch();
    info.platform = process.platform;
    info.version = NylasEnv.getVersion();
    info.processWorkingSetSize = workingSetSize;
    info.processPrivateBytes = privateBytes;
    info.processSharedBytes = sharedBytes;

    try {
      if (isClientEnv()) {
        if (NylasEnv.inDevMode()) { return }

        if (!info.accountId) {
          throw new Error("Metrics Reporter: You must include an accountId");
        }

        const {N1CloudAPI, NylasAPIRequest} = require('nylas-exports') // eslint-disable-line
        const req = new NylasAPIRequest({
          api: N1CloudAPI,
          options: {
            path: `/ingest-metrics`,
            method: 'POST',
            body: info,
            accountId: info.accountId,
          },
        });
        await req.run()
      } else {
        this.sendToHoneycomb(info)
      }
      logger.log(info, "Metrics Reporter: Submitted.", info);
    } catch (err) {
      logger.warn("Metrics Reporter: Submission Failed.", {error: err, ...info});
    }
  }
}

export default new MetricsReporter();
