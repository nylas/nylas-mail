import sleep from './utils'

// How many times do we retry an action.
const MAX_RETRIES = 30;

export default class ExpiredDataWorker {
  async run(metadatum) {
    console.log("Processing metadatum");
    let count = 0;
    do {
      try {
        await this.performAction(metadatum);

        // Now, get rid of the entry.
        await this.removeEntry(metadatum);
        return;
      } catch (err) {
        // We only try to perform the action for MAX_RETRIES.
        console.log("Error when performing action", err);
        count++;
        await sleep(60000 * (count + 1) + Math.floor((Math.random() * 100)));
      }
    } while (count < MAX_RETRIES);

    await this.removeEntry(metadatum);
  }

  async removeEntry(metadatum) {
    // Remove the object
    console.log("Destroying metadata");
    await metadatum.destroy();
  }

  async performAction(metadatum) {
    // You need to override this one.
    throw new Error("You should override this!");
  }
}
