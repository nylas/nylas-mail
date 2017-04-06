/* eslint global-require: 0 */

import crypto from 'crypto';
import {CommonProviderSettings} from 'isomorphic-core'
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
  "imap_security",
  "imap_allow_insecure_ssl",
  "smtp_host",
  "smtp_port",
  "smtp_username",
  "smtp_password",
  "smtp_security",
  "smtp_allow_insecure_ssl",
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

const NO_AUTH = { user: '', pass: '', sendImmediately: true };

export async function makeGmailOAuthRequest(sessionKey) {
  const remoteRequest = new NylasAPIRequest({
    api: N1CloudAPI,
    options: {
      path: `/auth/gmail/token?key=${sessionKey}`,
      method: 'GET',
      auth: NO_AUTH,
    },
  });
  return remoteRequest.run()
}

export async function authIMAPForGmail(tokenData) {
  const localRequest = new NylasAPIRequest({
    api: NylasAPI,
    options: {
      path: `/auth`,
      method: 'POST',
      auth: NO_AUTH,
      timeout: 1000 * 90, // Connecting to IMAP could take up to 90 seconds, so we don't want to hang up too soon
      body: {
        email: tokenData.email_address,
        name: tokenData.name,
        provider: 'gmail',
        settings: {
          xoauth2: tokenData.resolved_settings.xoauth2,
          expiry_date: tokenData.resolved_settings.expiry_date,
        },
      },
    },
  })
  const localJSON = await localRequest.run()
  const account = Object.assign({}, localJSON);
  account.localToken = localJSON.account_token;
  account.cloudToken = tokenData.account_token;
  return account
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
      timeout: 1000 * 180, // Same timeout as server timeout (most requests are faster than 90s, but server validation can be slow in some cases)
      body: data,
      auth: noauth,
    },
  })
  return n1CloudIMAPAuthRequest.run().then((remoteJSON) => {
    const localSyncIMAPAuthRequest = new NylasAPIRequest({
      api: NylasAPI,
      options: {
        path: `/auth`,
        method: 'POST',
        timeout: 1000 * 180, // Same timeout as server timeout (most requests are faster than 90s, but server validation can be slow in some cases)
        body: data,
        auth: noauth,
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
  const {email, type} = existingAccountInfo;
  const domain = email.split('@').pop().toLowerCase();
  let template = CommonProviderSettings[domain] || CommonProviderSettings[type] || {};
  if (template.alias) {
    template = CommonProviderSettings[template.alias];
  }

  const usernameWithFormat = (format) => {
    if (format === 'email') {
      return email
    }
    if (format === 'email-without-domain') {
      return email.split('@').shift();
    }
    return undefined;
  }

  const defaults = {
    imap_host: template.imap_host,
    imap_port: template.imap_port || 993,
    imap_username: usernameWithFormat(template.imap_user_format),
    imap_password: existingAccountInfo.password,
    imap_security: template.imap_security || "SSL / TLS",
    imap_allow_insecure_ssl: template.imap_allow_insecure_ssl || false,
    smtp_host: template.smtp_host,
    smtp_port: template.smtp_port || 587,
    smtp_username: usernameWithFormat(template.smtp_user_format),
    smtp_password: existingAccountInfo.password,
    smtp_security: template.smtp_security || "STARTTLS",
    smtp_allow_insecure_ssl: template.smtp_allow_insecure_ssl || false,
  }

  return Object.assign({}, existingAccountInfo, defaults);
}
