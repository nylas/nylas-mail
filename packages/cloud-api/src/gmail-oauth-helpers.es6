import google from 'googleapis';
import {Provider, IMAPConnection} from 'isomorphic-core'
import {DatabaseConnector} from 'cloud-core';
import Serialization from './serialization';

const OAuth2 = google.auth.OAuth2;
const {GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL} = process.env;

class GmailOAuthHelpers {
  newOAuthClient() {
    return new OAuth2(GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL);
  }

  async exchangeCodeForGoogleToken(client, oAuthCode) {
    return new Promise((resolve, reject) => {
      client.getToken(oAuthCode, (err, googleToken) => {
        if (err) {
          return reject(err)
        }
        client.setCredentials(googleToken);
        return resolve(googleToken)
      })
    })
  }

  async fetchGoogleProfile(client) {
    return new Promise((resolve, reject) => {
      google.oauth2({version: 'v2', auth: client})
      .userinfo.get((err, googleProfile) => {
        if (err) {
          return reject(err)
        }
        return resolve(googleProfile)
      })
    })
  }

  imapSettings(googleToken, googleProfile) {
    return {
      connection: {
        imap_username: googleProfile.email,
        imap_host: 'imap.gmail.com',
        imap_port: 993,
        ssl_required: true,
      },
      credentials: {
        refresh_token: googleToken.refresh_token,
        expiry_date: googleToken.expiry_date,
        client_id: GMAIL_CLIENT_ID,
        client_secret: GMAIL_CLIENT_SECRET,
      },
    }
  }

  async resolveIMAPSettings(imapSettings, logger) {
    const imap = await IMAPConnection.connect({
      logger: logger,
      settings: Object.assign({},
        imapSettings.connection,
        imapSettings.credentials
      ),
      db: {},
    })
    imap.end();
    return imap.resolvedSettings
  }

  async createCloudAccount(imapSettings, googleProfile) {
    const db = await DatabaseConnector.forShared()
    return db.Account.upsertWithCredentials({
      name: googleProfile.name,
      provider: Provider.Gmail,
      emailAddress: googleProfile.email,
      connectionSettings: imapSettings.connection,
    }, imapSettings.credentials)
  }

  async createPendingAuthResponse({account, token}, imapSettings, n1Key) {
    const response = account.toJSON();
    response.account_token = token.value;
    response.resolved_settings = imapSettings.resolved;

    const db = await DatabaseConnector.forShared()
    return db.PendingAuthResponse.create({
      response: Serialization.jsonStringify(response),
      pendingAuthKey: n1Key,
    })
  }
}
export default new GmailOAuthHelpers()
