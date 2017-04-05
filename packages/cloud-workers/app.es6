import _ from 'underscore'
import SnoozeWorker from './workers/snooze'
import SendRemindersWorker from './workers/send-reminders'
import SendLaterWorker from './workers/send-later'
import {setupMonitoring} from './monitoring'
import Sentry from './sentry'
const {DatabaseConnector, Logger, Metrics} = require('cloud-core')

// Swap out Node's native Promise for Bluebird, which allows us to
// do fancy things like handle exceptions inside promise blocks
global.Promise = require('bluebird');

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
    const snoozeWorker = new SnoozeWorker(logger);
    const sendWorker = new SendLaterWorker(logger);
    const remindersWorker = new SendRemindersWorker(logger);

    for (const datum of expiredMetadata) {
      // Skip entries we're already processing.
      if (workerTable[datum.id]) {
        continue;
      }

      switch (datum.pluginId) {
        case 'n1-send-later':
          workerTable[datum.id] = sendWorker.run(datum);
          break;
        case 'thread-snooze':
          workerTable[datum.id] = snoozeWorker.run(datum);
          break;
        case 'send-reminders':
          workerTable[datum.id] = remindersWorker.run(datum);
          break;
        default:
          logger.warn(`Unknown plugin type ${datum.pluginId}, skipping.`)
          continue;
      }

      workerTable[datum.id].then(() => {
        logger.info(`Worker for task ${datum.id} completed.`);
        delete workerTable[datum.id];
      })
    }
  } catch (e) {
    Sentry.captureException(e);
    logger.error(e, "Exception in main loop");
  }

  global.lastRun = new Date();
  setTimeout(run, 60000);
}

function main() {
  setupMonitoring(global.Logger);
  run();
}

main();
