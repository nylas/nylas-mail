import {DatabaseConnector} from 'cloud-core'
import ExpiredDataWorker from './expired-data-worker'
import {asyncGetImapConnection} from './utils'

// FIXME: change this to something like "Nylas Snoozed".
const SNOOZE_FOLDER_NAME = "N1-Snoozed";

export default class SnoozeWorker extends ExpiredDataWorker {
  pluginId() {
    return 'thread-snooze'
  }

  async performAction(metadatum) {
    if (!metadatum.value.header) {
      throw new Error("Can't unsnooze, no message-id-header")
    }

    const db = await DatabaseConnector.forShared()
    const conn = await asyncGetImapConnection(db, metadatum.accountId, this.logger)
    await conn.connect();
    const box = await conn.openBox(SNOOZE_FOLDER_NAME)
    const results = await box.search([['HEADER', 'MESSAGE-ID', metadatum.value.header]])

    this.logger.debug(`Found ${results.length} message with HEADER MESSAGE-ID: ${metadatum.value.header}. Moving back to Inbox.`);

    for (const result of results) {
      box.moveFromBox(result, "INBOX")
    }
  }
}
