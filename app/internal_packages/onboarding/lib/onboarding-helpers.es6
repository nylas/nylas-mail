/* eslint global-require: 0 */

import crypto from 'crypto';
import { CommonProviderSettings } from 'imap-provider-settings';
import {
  Account,
  MailspringAPIRequest,
  IdentityStore,
  RegExpUtils,
  MailsyncProcess,
} from 'mailspring-exports';

const { makeRequest, rootURLForServer } = MailspringAPIRequest;

function base64URL(inBuffer) {
  let buffer;
  if (typeof inBuffer === 'string') {
    buffer = new Buffer(inBuffer);
  } else if (inBuffer instanceof Buffer) {
    buffer = inBuffer;
  } else {
    throw new Error(`${inBuffer} must be a string or Buffer`);
  }
  return buffer
    .toString('base64')
    .replace(/\+/g, '-') // Convert '+' to '-'
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
  };

  const idString = `${emailAddress}${JSON.stringify(settingsThatCouldChangeMailContents)}`;
  return crypto
    .createHash('sha256')
    .update(idString, 'utf8')
    .digest('hex')
    .substr(0, 8);
}

export function expandAccountWithCommonSettings(account) {
  const domain = account.emailAddress
    .split('@')
    .pop()
    .toLowerCase();
  let template = CommonProviderSettings[domain] || CommonProviderSettings[account.provider] || {};
  if (template.alias) {
    template = CommonProviderSettings[template.alias];
  }

  const usernameWithFormat = format => {
    if (format === 'email') {
      return account.emailAddress;
    }
    if (format === 'email-without-domain') {
      return account.emailAddress.split('@').shift();
    }
    return undefined;
  };

  const populated = account.clone();

  populated.settings = Object.assign(
    {
      imap_host: template.imap_host,
      imap_port: template.imap_port || 993,
      imap_username: usernameWithFormat(template.imap_user_format),
      imap_password: populated.settings.imap_password,
      imap_security: template.imap_security || 'SSL / TLS',
      imap_allow_insecure_ssl: template.imap_allow_insecure_ssl || false,
      smtp_host: template.smtp_host,
      smtp_port: template.smtp_port || 587,
      smtp_username: usernameWithFormat(template.smtp_user_format),
      smtp_password: populated.settings.smtp_password || populated.settings.imap_password,
      smtp_security: template.smtp_security || 'STARTTLS',
      smtp_allow_insecure_ssl: template.smtp_allow_insecure_ssl || false,
    },
    populated.settings
  );

  return populated;
}

export function makeGmailOAuthRequest(sessionKey) {
  return makeRequest({
    server: 'identity',
    path: `/auth/gmail/token?key=${sessionKey}`,
    method: 'GET',
    auth: false,
  });
}

export async function buildGmailAccountFromToken(serverTokenResponse) {
  // At this point, the Mailspring server has retrieved the Gmail token,
  // created an account object in the database and tested it. All we
  // need to do is save it locally, since we're confident Gmail will be
  // accessible from the local sync worker.
  const { name, emailAddress, refreshToken } = serverTokenResponse;

  const account = expandAccountWithCommonSettings(
    new Account({
      name: name,
      emailAddress: emailAddress,
      provider: 'gmail',
      settings: {
        refresh_token: refreshToken,
      },
    })
  );

  account.id = idForAccount(emailAddress, account.settings);

  return account;
}

export function buildGmailSessionKey() {
  return base64URL(crypto.randomBytes(40));
}

export function buildGmailAuthURL(sessionKey) {
  return `${rootURLForServer('identity')}/auth/gmail?state=${sessionKey}`;
}

export async function finalizeAndValidateAccount(account) {
  account.id = idForAccount(account.emailAddress, account.settings);

  // handle special case for exchange/outlook/hotmail username field
  account.settings.username = account.settings.username || account.settings.email;

  if (account.settings.imap_port) {
    account.settings.imap_port /= 1;
  }
  if (account.settings.smtp_port) {
    account.settings.smtp_port /= 1;
  }
  if (account.label && account.label.includes('@')) {
    account.label = account.emailAddress;
  }

  // Test connections to IMAP and SMTP
  const proc = new MailsyncProcess(AppEnv.getLoadSettings(), IdentityStore.identity(), account);
  const response = await proc.test();
  return new Account(response.account);
}

export function isValidHost(value) {
  return RegExpUtils.domainRegex().test(value) || RegExpUtils.ipAddressRegex().test(value);
}
