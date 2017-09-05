/* eslint global-require: 0 */

import crypto from 'crypto';
import {CommonProviderSettings} from 'imap-provider-settings';
import {
  NylasAPIRequest,
  IdentityStore,
  RegExpUtils,
  MailsyncProcess,
} from 'nylas-exports';

const {makeRequest, rootURLForServer} = NylasAPIRequest;

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

export function makeGmailOAuthRequest(sessionKey) {
  return makeRequest({
    server: 'accounts',
    path: `/auth/gmail/token?key=${sessionKey}`,
    method: 'GET',
    auth: false,
  });
}

export async function authIMAPForGmail(serverTokenResponse) {
  // At this point, the Mailspring server has retrieved the Gmail token,
  // created an account object in the database and tested it. All we
  // need to do is save it locally, since we're confident Gmail will be
  // accessible from the local sync worker.
  const {id, email_address, provider, connection_settings, account_token, xoauth_refresh_token, name} = serverTokenResponse;

  // Todo: clean up the serialization so this translation from K2 JSON isn't necessary.
  return {
    account: {
      id,
      provider,
      name,
      emailAddress: email_address,
      settings: Object.assign({}, connection_settings, {
        xoauth_refresh_token,
      }),
    },
    cloudToken: account_token,
  };
}

export function buildGmailSessionKey() {
  return base64url(crypto.randomBytes(40));
}

export function buildGmailAuthURL(sessionKey) {
  return `${rootURLForServer('accounts')}/auth/gmail?state=${sessionKey}`;
}

export async function runAuthValidation(accountInfo) {
  const {username, type, email, name} = accountInfo;

  const data = {
    id: 'temp',
    provider: type,
    name: name,
    emailAddress: email,
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

  // Only include the required IMAP fields. Auth validation does not allow extra fields
  if (type !== "gmail") {
    for (const key of Object.keys(data.settings)) {
      if (!IMAP_FIELDS.has(key)) {
        delete data.settings[key];
      }
    }
  }

  // Test the account locally - if it succeeds, send it to the server and test it there

  const proc = new MailsyncProcess(NylasEnv.getLoadSettings(), IdentityStore.identity(), data);
  const {account} = await proc.test();

  delete data.id;

  const {id, account_token} = await makeRequest({
    server: 'accounts',
    path: `/auth`,
    method: 'POST',
    timeout: 1000 * 180, // Same timeout as server timeout (most requests are faster than 90s, but server validation can be slow in some cases)
    body: data,
    auth: false,
  })

  return {
    account: Object.assign({}, account, {id}),
    cloudToken: account_token,
  };
}

export function isValidHost(value) {
  return RegExpUtils.domainRegex().test(value) || RegExpUtils.ipAddressRegex().test(value);
}

export function expandAccountInfoWithCommonSettings(accountInfo) {
  const {email, type} = accountInfo;
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
    imap_password: accountInfo.password,
    imap_security: template.imap_security || "SSL / TLS",
    imap_allow_insecure_ssl: template.imap_allow_insecure_ssl || false,
    smtp_host: template.smtp_host,
    smtp_port: template.smtp_port || 587,
    smtp_username: usernameWithFormat(template.smtp_user_format),
    smtp_password: accountInfo.password,
    smtp_security: template.smtp_security || "STARTTLS",
    smtp_allow_insecure_ssl: template.smtp_allow_insecure_ssl || false,
  }

  return Object.assign({}, accountInfo, defaults);
}
