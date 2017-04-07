/* eslint object-property-newline:0 */
import Foreman from './src/foreman'
import SnoozeWorker from './src/workers/snooze'
import SendLaterWorker from './src/workers/send-later'
import SendRemindersWorker from './src/workers/send-reminders'
import {setupMonitoring} from './src/monitoring'
const {DatabaseConnector, Logger} = require('cloud-core')

global.Promise = require('bluebird');
const onUnhandledError = (err) => { global.Logger.error(err) }
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)

global.Logger = Logger.createLogger('cloud-workers')

async function main() {
  setupMonitoring(global.Logger);
  const db = await DatabaseConnector.forShared();
  const logger = global.Logger;

  logger.info("Starting Cloud Workers")

  const foremans = [
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

main();
