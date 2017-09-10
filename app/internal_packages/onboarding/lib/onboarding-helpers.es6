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

function idForAccount(emailAddress, connectionSettings) {
  // changing your connection security settings / ports shouldn't blow
  // away everything and trash your metadata. Just look at critiical fields.
  // (Me adding more connection settings fields shouldn't break account Ids either!)
  const settingsThatCouldChangeMailContents = {
    imap_username: connectionSettings.imap_username,
    imap_host: connectionSettings.imap_host,
    smtp_username: connectionSettings.smtp_username,
    smtp_host: connectionSettings.smtp_host,
  }

  const idString = `${emailAddress}${JSON.stringify(settingsThatCouldChangeMailContents)}`;
  return crypto.createHash('sha256').update(idString, 'utf8').digest('hex');
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
  const {emailAddress, refreshToken} = serverTokenResponse;
  const settings = expandAccountInfoWithCommonSettings({email: emailAddress, refreshToken, type: 'gmail'});

  return {
    id: idForAccount(emailAddress, settings),
    provider: 'gmail',
    name,
    settings,
    emailAddress,
  };
}

export function buildGmailSessionKey() {
  return base64url(crypto.randomBytes(40));
}

export function buildGmailAuthURL(sessionKey) {
  return `${rootURLForServer('accounts')}/auth/gmail?state=${sessionKey}`;
}

export async function buildAndValidateAccount(accountInfo) {
  const {username, type, email, name} = accountInfo;

  const data = {
    id: idForAccount(email, accountInfo),
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

  return account;
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
