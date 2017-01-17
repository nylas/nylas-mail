/* eslint global-require: 0 */

import crypto from 'crypto';
import {
  N1CloudAPI,
  NylasAPI,
  NylasAPIRequest,
  RegExpUtils,
} from 'nylas-exports';

const IMAP_FIELDS = new Set([
  "imap_host",
  "imap_port",
  "imap_username",
  "imap_password",
  "smtp_host",
  "smtp_port",
  "smtp_username",
  "smtp_password",
  "smtp_custom_config",
  "ssl_required",
]);

function base64url(inBuffer) {
  let buffer;
  if (typeof inBuffer === "string") {
    buffer = new Buffer(inBuffer);
  } else if (inBuffer instanceof Buffer) {
    buffer = inBuffer;
  } else {
    throw new Error(`${inBuffer} must be a string or Buffer`)
  }
  return buffer.toString('base64')
    .replace(/\+/g, '-')  // Convert '+' to '-'
    .replace(/\//g, '_'); // Convert '/' to '_'
}

export async function makeGmailOAuthRequest(sessionKey, callback) {
  const noauth = {
    user: '',
    pass: '',
    sendImmediately: true,
  };
  const remoteRequest = new NylasAPIRequest({
    api: N1CloudAPI,
    options: {
      path: `/auth/gmail/token?key=${sessionKey}`,
      method: 'GET',
      error: callback,
      auth: noauth,
    },
  });
  let remoteJSON = {}
  try {
    remoteJSON = await remoteRequest.run()
  } catch (err) {
    if (err.statusCode === 404) {
      return
    }
    throw err
  }
  const localRequest = new NylasAPIRequest({
    api: NylasAPI,
    options: {
      path: `/auth`,
      method: 'POST',
      auth: noauth,
      body: {
        email: remoteJSON.email_address,
        name: remoteJSON.name,
        provider: 'gmail',
        settings: {
          xoauth2: remoteJSON.resolved_settings.xoauth2,
          expiry_date: remoteJSON.resolved_settings.expiry_date,
        },
      },
    },
  })
  const localJSON = await localRequest.run()
  const account = Object.assign({}, localJSON);
  account.localToken = localJSON.account_token;
  account.cloudToken = remoteJSON.account_token;
  callback(null, account);
}

export function buildGmailSessionKey() {
  return base64url(crypto.randomBytes(40));
}

export function buildGmailAuthURL(sessionKey) {
  return `${N1CloudAPI.APIRoot}/auth/gmail?state=${sessionKey}`;
}

export function runAuthRequest(accountInfo) {
  const {username, type, email, name} = accountInfo;

  const data = {
    provider: type,
    email: email,
    name: name,
    settings: Object.assign({}, accountInfo),
  };

  // handle special case for exchange/outlook/hotmail username field
  data.settings.username = username || email;

  if (data.settings.imap_port) {
    data.settings.imap_port /= 1;
  }
  if (data.settings.smtp_port) {
    data.settings.smtp_port /= 1;
  }
  // if there's an account with this email, get the ID for it to notify the backend of re-auth
  // const account = AccountStore.accountForEmail(accountInfo.email);
  // const reauthParam = account ? `&reauth=${account.id}` : "";

  /**
   * Only include the required IMAP fields. Auth validation does not allow
   * extra fields
   */
  if (type !== "gmail" && type !== "office365") {
    for (const key of Object.keys(data.settings)) {
      if (!IMAP_FIELDS.has(key)) {
        delete data.settings[key]
      }
    }
  }

  const noauth = {
    user: '',
    pass: '',
    sendImmediately: true,
  };

  // Send the form data directly to Nylas to get code
  // If this succeeds, send the received code to N1 server to register the account
  // Otherwise process the error message from the server and highlight UI as needed
  const n1CloudIMAPAuthRequest = new NylasAPIRequest({
    api: N1CloudAPI,
    options: {
      path: '/auth',
      method: 'POST',
      body: data,
      auth: noauth,
      returnsModel: false,
    },
  })
  return n1CloudIMAPAuthRequest.run().then((remoteJSON) => {
    const localSyncIMAPAuthRequest = new NylasAPIRequest({
      api: NylasAPI,
      options: {
        path: `/auth`,
        method: 'POST',
        body: data,
        auth: noauth,
        returnsModel: false,
      },
    })
    return localSyncIMAPAuthRequest.run().then((localJSON) => {
      const accountWithTokens = Object.assign({}, localJSON);
      accountWithTokens.localToken = localJSON.account_token;
      accountWithTokens.cloudToken = remoteJSON.account_token;
      return accountWithTokens
    })
  })
}

export function isValidHost(value) {
  return RegExpUtils.domainRegex().test(value) || RegExpUtils.ipAddressRegex().test(value);
}

export function accountInfoWithIMAPAutocompletions(existingAccountInfo) {
  const CommonProviderSettings = require('./common-provider-settings.json');

  const {email, type} = existingAccountInfo;
  const domain = email.split('@').pop().toLowerCase();
  const template = CommonProviderSettings[domain] || CommonProviderSettings[type] || {};

  const usernameWithFormat = (format) => {
    if (format === 'email') {
      return email
    }
    if (format === 'email-without-domain') {
      return email.split('@').shift();
    }
    return undefined;
  }

  // always pre-fill SMTP / IMAP username, password and port.
  const defaults = {
    imap_host: template.imap_host,
    imap_port: template.imap_port || 993,
    imap_username: usernameWithFormat(template.imap_user_format),
    imap_password: existingAccountInfo.password,
    smtp_host: template.smtp_host,
    smtp_port: template.smtp_port || 587,
    smtp_username: usernameWithFormat(template.smtp_user_format),
    smtp_password: existingAccountInfo.password,
    ssl_required: (template.ssl === '1'),
    smtp_custom_config: template.smtp_custom_config,
  }

  return Object.assign({}, existingAccountInfo, defaults);
}
