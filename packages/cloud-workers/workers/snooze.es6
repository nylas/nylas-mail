import {DatabaseConnector, GmailOAuthHelpers} from 'cloud-core'
import ExpiredDataWorker from './expired-data-worker'
import {IMAPConnection, IMAPErrors} from '../../isomorphic-core'

// FIXME: change this to something like "Nylas Snoozed".
const SNOOZE_FOLDER_NAME = "N1-Snoozed";


export default class SnoozeWorker extends ExpiredDataWorker {
  async performAction(metadatum) {
    const db = await DatabaseConnector.forShared();
    const account = await db.Account.find({where: {id: metadatum.accountId}})
    const settings = account.connectionSettings;
    const credentials = account.decryptedCredentials();
    console.log(metadatum.value.header);

    const currentUnixDate = Math.floor(Date.now() / 1000);
    if (account.provider === 'gmail' && currentUnixDate > credentials.expiry_date) {
      console.log("Refreshing access token");
      await GmailOAuthHelpers.refreshAccessToken(account);
    }

    const conn = new IMAPConnection({
      db: db,
      settings: Object.assign({}, settings, credentials),
      logger: console,
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
