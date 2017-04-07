import CloudWorker from '../cloud-worker'

// FIXME: change this to something like "Nylas Snoozed".
const SNOOZE_FOLDER_NAME = "N1-Snoozed";

export default class SnoozeWorker extends CloudWorker {
  pluginId() {
    return 'thread-snooze'
  }

  async performAction({metadatum, connection}) {
    if (!metadatum.value.header) {
      throw new Error("Can't unsnooze, no message-id-header")
    }

    const box = await connection.openBox(SNOOZE_FOLDER_NAME)
    const results = await box.search([['HEADER', 'MESSAGE-ID', metadatum.value.header]])

    this.logger.debug(`Found ${results.length} message with HEADER MESSAGE-ID: ${metadatum.value.header}. Moving back to Inbox.`);

    for (const result of results) {
      box.moveFromBox(result, "INBOX")
    }
  }
}
