import {sleep} from './utils'
import Sentry from '../sentry'

// How many times do we retry an action.
const MAX_RETRIES = 30;

export default class ExpiredDataWorker {
  constructor(logger) {
    this.logger = logger.child({pluginId: this.pluginId()});
  }

  pluginId() {
    throw new Error("You should override this!");
  }

  async run(metadatum) {
    this.logger.info(`Processing metadatum w/ id ${metadatum.id}`);
    let count = 0;
    do {
      try {
        await this.performAction(metadatum);
        await this.nullifyEntry(metadatum); // So we don't try to process it again
        return;
      } catch (err) {
        // We only try to perform the action for
        Sentry.captureException(err);

        if (/invalid metadata values/i.test(err.message)) {
          this.logger.error("Cannot process metadatum, will not retry.", err)
          count = MAX_RETRIES;
        } else {
          count++;
          const sleepPeriod = 60000 * (count + 1) + Math.floor((Math.random() * 100));

          this.logger.error("Error when performing action", err);
          this.logger.error(`Sleeping for ${sleepPeriod} ms`);
          await sleep(sleepPeriod);
        }
      }
    } while (count < MAX_RETRIES);

    await this.removeEntry(metadatum);
  }

  async nullifyEntry(metadatum) {
    // Nylas Mail can't properly process delete deltas for metadata, because
    // the transactions don't store what the objectId and pluginId of the
    // metadata were. Instead, we just nullify the value.
    this.logger.info(`Nullifying metadata for ${metadatum.id}`);
    metadatum.value = {};
    metadatum.expiration = null;
    await metadatum.save();
  }

  async performAction(metadatum) {
    // You need to override this one.
    throw new Error("You should override this!");
  }
}
