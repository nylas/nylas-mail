import _ from 'underscore'
import SnoozeWorker from './workers/snooze'
import SendRemindersWorker from './workers/send-reminders'
import {setupMonitoring} from './monitoring'
import Sentry from './sentry'
const {DatabaseConnector, Logger, Metrics} = require('cloud-core')

Metrics.startCapturing('n1-cloud-workers')

global.Metrics = Metrics
global.Logger = Logger.createLogger('n1-cloud-workers')

const onUnhandledError = (err) => {
  global.Logger.fatal(err, 'Unhandled error')
  global.Metrics.reportError(err)
}
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)

const workerTable = {};
const MAX_ELEMENTS = 1000;

const workers = [
  new SnoozeWorker(global.Logger),
  new SendRemindersWorker(global.Logger),
]
const workersByPluginId = {}
workers.forEach((worker) => { workersByPluginId[worker.pluginId()] = worker })

// Ghetto check-in mechanism. We really want to be alerted
// if for some reason our main loop blows up. To do that, we just
// save the last time we've been through the loop in lastRun. Our
// watchdog endpoint checks that the value is always < to 5 min.
global.lastRun = new Date();

async function run() {
  const logger = global.Logger;
  const now = new Date();
  const db = await DatabaseConnector.forShared();
  const expiredMetadata = await db.Metadata.findAll({
    limit: MAX_ELEMENTS,
    where: {
      expiration: {
        $lte: now,
      },
    },
  });

  logger.info(`Fetched ${expiredMetadata.length} expired elements from the db`);

  try {
    const expiredMetadataByPluginId = _.groupBy(expiredMetadata, (datum) => datum.pluginId)
    for (const pluginId of Object.keys(expiredMetadataByPluginId)) {
      const worker = workersByPluginId[pluginId]
      if (!worker) {
        throw new Error(`Could not find worker for pluginId ${pluginId}`)
      }
      for (const datum of expiredMetadataByPluginId[pluginId]) {
        // Skip entries we're already processing.
        if (workerTable[datum.id]) {
          logger.info(`Skipping metadum with id ${datum.id}, it's already being processed`)
          continue;
        }
        workerTable[datum.id] = worker.run(datum)
        workerTable[datum.id].then(() => {
          logger.info(`Worker for task ${datum.id} completed.`);
          delete workerTable[datum.id];
        })
      }
    }
  } catch (e) {
    Sentry.captureException(e);
    logger.error("Exception in main loop", e);
  }

  global.lastRun = new Date();
  setTimeout(run, 60000);
}

function main() {
  setupMonitoring(global.Logger);
  run();
}

main();
