import google from 'googleapis';
import {Provider, IMAPConnection, AuthHelpers} from 'isomorphic-core'
import DatabaseConnector from './database-connector'

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

  async resolveIMAPSettings(imapSettings, logger) {
    const imap = await IMAPConnection.connect({
      logger: logger,
      settings: Object.assign({},
        imapSettings.connectionSettings,
        imapSettings.connectionCredentials,
      ),
      db: {},
    })
    imap.end();
    return imap.getResolvedSettings()
  }

  async createCloudAccount(imapSettings, googleProfile) {
    const db = await DatabaseConnector.forShared()
    return db.Account.upsertWithCredentials({
      name: googleProfile.name,
      provider: Provider.Gmail,
      emailAddress: googleProfile.email,
      connectionSettings: imapSettings.connectionSettings,
    }, imapSettings.connectionCredentials)
  }

  async refreshAccessToken(account) {
    const oauthClient = new OAuth2(GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL);
    const credentials = account.decryptedCredentials()
    const refreshToken = credentials.refresh_token;
    oauthClient.setCredentials({ refresh_token: refreshToken });

    return new Promise((resolve, reject) => {
      oauthClient.refreshAccessToken(async (err, tokens) => {
        if (err) {
          reject(err);
        }
        const res = {}
        res.access_token = tokens.access_token;
        res.xoauth2 = AuthHelpers.generateXOAuth2Token(account.emailAddress,
                                                tokens.access_token);
        res.expiry_date = Math.floor(tokens.expiry_date / 1000);
        const newCredentials = Object.assign(credentials, res);
        account.setCredentials(newCredentials);
        await account.save();
        resolve(newCredentials);
      });
    });
  }

  async createPendingAuthResponse({account, token}, imapSettings, n1Key) {
    const response = account.toJSON();
    response.account_token = token.value;
    response.resolved_settings = imapSettings.resolved;

    const db = await DatabaseConnector.forShared()
    return db.PendingAuthResponse.create({
      response: JSON.stringify(response),
      pendingAuthKey: n1Key,
    })
  }
}
export default new GmailOAuthHelpers()
