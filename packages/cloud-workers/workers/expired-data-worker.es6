import sleep from './utils'
import Sentry from '../sentry'

// How many times do we retry an action.
const MAX_RETRIES = 30;

export default class ExpiredDataWorker {
  constructor(logger) {
    this.logger = logger;
  }

  async run(metadatum) {
    this.logger.info(`Processing metadatum w/ id ${metadatum.id}`);
    let count = 0;
    do {
      try {
        await this.performAction(metadatum);

        // Now, get rid of the entry.
        await this.removeEntry(metadatum);
        return;
      } catch (err) {
        // We only try to perform the action for
        Sentry.captureException(err);
        count++;
        const sleepPeriod = 60000 * (count + 1) + Math.floor((Math.random() * 100));

        this.logger.error("Error when performing action", err);
        this.logger.error(`Sleeping for ${sleepPeriod} ms`);
        await sleep(sleepPeriod);
      }
    } while (count < MAX_RETRIES);

    await this.removeEntry(metadatum);
  }

  async removeEntry(metadatum) {
    // Remove the object
    this.logger.info(`Destroying metadata for ${metadatum.id}`);
    await metadatum.destroy();
  }

  async performAction(metadatum) {
    // You need to override this one.
    throw new Error("You should override this!");
  }
}
