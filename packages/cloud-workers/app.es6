import SnoozeWorker from './workers/snooze'
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

async function run() {
  const now = new Date();
  const db = await DatabaseConnector.forShared();
  const expiredMetadata = await db.Metadata.findAll({
    limit: MAX_ELEMENTS,
    where: {
      expirationDate: {
        $lte: now,
      },
    },
  });

  try {
    const snoozeWorker = new SnoozeWorker();
    for (const datum of expiredMetadata) {
      // Skip entries we're already processing.
      if (workerTable[datum.id]) {
        continue;
      }

      workerTable[datum.id] = snoozeWorker.run(datum);
      workerTable[datum.id].then(() => {
        console.log("Deleting from the table");
        delete workerTable[datum.id];
      })
    }
  } catch (e) {
    console.log("Exception in main loop", e);
  }

  setTimeout(run, 60000);
}

run();
