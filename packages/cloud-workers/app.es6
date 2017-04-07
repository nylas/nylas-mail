/* eslint object-property-newline:0 */
import Foreman from './src/foreman'
import SnoozeWorker from './src/workers/snooze'
import SendLaterWorker from './src/workers/send-later'
import SendRemindersWorker from './src/workers/send-reminders'
import {setupMonitoring} from './src/monitoring'
const {DatabaseConnector, Logger} = require('cloud-core')

global.Promise = require('bluebird');
global.Logger = Logger.createLogger('cloud-workers')

let foremans = []
async function start() {
  const db = await DatabaseConnector.forShared();
  const logger = global.Logger;

  logger.info("Starting Cloud Workers")

  foremans = [
    new Foreman({db, logger,
      pluginId: "thread-snooze",
      WorkerClass: SnoozeWorker,
    }),
    new Foreman({db, logger,
      pluginId: "n1-send-later",
      WorkerClass: SendLaterWorker,
    }),
    new Foreman({db, logger,
      pluginId: "send-reminders",
      WorkerClass: SendRemindersWorker,
    }),
  ]
  foremans.forEach(f => f.run()) // Don't await
}

let restartTimeout = null;
async function restart() {
  global.Logger.warn("Restarting app due to unhandled error")
  clearTimeout(restartTimeout);
  foremans.forEach(f => f.stop());
  restartTimeout = setTimeout(() => {
    start();
  }, 30 * 1000);
}

const onUnhandledError = (err) => {
  restart();
  global.Logger.error(err)
}
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)

setupMonitoring(global.Logger);
start();
