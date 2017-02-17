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
    this.logger.debug(`Snoozed message message-id-header: ${metadatum.value.header}`);

    const db = await DatabaseConnector.forShared()
    const conn = await asyncGetImapConnection(db, metadatum.accountId, this.logger)
    await conn.connect();
    const box = await conn.openBox(SNOOZE_FOLDER_NAME)
    const results = await box.search([['HEADER', 'MESSAGE-ID', metadatum.value.header]])
    for (const result of results) {
      box.moveFromBox(result, "INBOX")
    }
  }
}
