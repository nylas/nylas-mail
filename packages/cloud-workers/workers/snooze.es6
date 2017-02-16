import {DatabaseConnector, GmailOAuthHelpers} from 'cloud-core'
import ExpiredDataWorker from './expired-data-worker'
import {IMAPConnection} from '../../isomorphic-core'

// FIXME: change this to something like "Nylas Snoozed".
const SNOOZE_FOLDER_NAME = "N1-Snoozed";


export default class SnoozeWorker extends ExpiredDataWorker {
  async performAction(metadatum) {
    const db = await DatabaseConnector.forShared();
    const account = await db.Account.find({where: {id: metadatum.accountId}})
    const settings = account.connectionSettings;
    const credentials = account.decryptedCredentials();
    this.logger.debug(`Snoozed message message-id-header: ${metadatum.value.header}`);

    const currentUnixDate = Math.floor(Date.now() / 1000);
    if (account.provider === 'gmail' && currentUnixDate > credentials.expiry_date) {
      this.logger.info(`Refreshing access token for account id: ${account.id}`);
      await GmailOAuthHelpers.refreshAccessToken(account);
    }

    const conn = new IMAPConnection({
      db: db,
      settings: Object.assign({}, settings, credentials),
      logger: this.logger,
    });

    settings.debug = console.log;

    await conn.connect();
    const box = await conn.openBox(SNOOZE_FOLDER_NAME)
    const results = await box.search([['HEADER', 'MESSAGE-ID', metadatum.value.header]])
    for (const result of results) {
      box.moveFromBox(result, "INBOX")
    }
  }
}
