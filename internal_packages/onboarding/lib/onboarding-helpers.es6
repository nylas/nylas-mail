/* eslint global-require: 0 */

import crypto from 'crypto';
import {EdgehillAPI, NylasAPI, AccountStore, RegExpUtils} from 'nylas-exports';
import url from 'url';

function base64url(buf) {
  return buf.toString('base64')
    .replace(/\+/g, '-')  // Convert '+' to '-'
    .replace(/\//g, '_'); // Convert '/' to '_'
}

export function pollForGmailAccount(sessionKey, callback) {
  EdgehillAPI.makeRequest({
    path: `/oauth/google/token?key=${sessionKey}`,
    method: "GET",
    error: callback,
    success: (json) => {
      if (json && json.data) {
        callback(null, JSON.parse(json.data));
      } else {
        callback(null, null);
      }
    },
  });
}

export function buildGmailSessionKey() {
  return base64url(crypto.randomBytes(40));
}

export function buildGmailAuthURL(sessionKey) {
  // Use a different app for production and development.
  const env = NylasEnv.config.get('env') || 'production';
  let googleClientId = '372024217839-cdsnrrqfr4d6b4gmlqepd7v0n0l0ip9q.apps.googleusercontent.com';
  if (env !== 'production') {
    googleClientId = '529928329786-e5foulo1g9kiej2h9st9sb0f4dt96s6v.apps.googleusercontent.com';
  }

  const encryptionKey = base64url(crypto.randomBytes(24));
  const encryptionIv = base64url(crypto.randomBytes(16));

  return url.format({
    protocol: 'https',
    host: 'accounts.google.com/o/oauth2/auth',
    query: {
      response_type: 'code',
      state: `${sessionKey},${encryptionKey},${encryptionIv},`,
      client_id: googleClientId,
      redirect_uri: `${EdgehillAPI.APIRoot}/oauth/google/callback`,
      access_type: 'offline',
      scope: `https://www.googleapis.com/auth/userinfo.email \
          https://www.googleapis.com/auth/userinfo.profile \
          https://mail.google.com/ \
          https://www.google.com/m8/feeds \
          https://www.googleapis.com/auth/calendar`,
      prompt: 'consent',
    },
  });
}

export function buildWelcomeURL(account) {
  return url.format({
    protocol: 'https',
    host: 'nylas.com/welcome',
    query: {
      n: base64url(NylasEnv.config.get("updateIdentity")),
      e: base64url(account.emailAddress),
      p: base64url(account.provider),
      a: base64url(account.id),
    },
  });
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
    data.settings.imap_port = data.settings.imap_port / 1;
  }
  if (data.settings.smtp_port) {
    data.settings.smtp_port = data.settings.smtp_port / 1;
  }
  // if there's an account with this email, get the ID for it to notify the backend of re-auth
  const account = AccountStore.accountForEmail(accountInfo.email);
  const reauthParam = account ? `&reauth=${account.id}` : "";

  // Send the form data directly to Nylas to get code
  // If this succeeds, send the received code to N1 server to register the account
  // Otherwise process the error message from the server and highlight UI as needed
  return NylasAPI.makeRequest({
    path: `/auth?client_id=${NylasAPI.AppID}&n1_id=${NylasEnv.config.get('updateIdentity')}${reauthParam}`,
    method: 'POST',
    body: data,
    returnsModel: false,
    timeout: 60000,
    auth: {
      user: '',
      pass: '',
      sendImmediately: true,
    },
  })
  .then((json) => {
    json.email = data.email;
    return EdgehillAPI.makeRequest({
      path: "/connect/nylas",
      method: "POST",
      timeout: 60000,
      body: json,
    })
  })
}

export function isValidHost(value) {
  return RegExpUtils.domainRegex().test(value) || RegExpUtils.ipAddressRegex().test(value);
}

export function accountInfoWithIMAPAutocompletions(existingAccountInfo) {
  const CommonProviderSettings = require('./common-provider-settings.json');

  const email = existingAccountInfo.email;
  const domain = email.split('@').pop().toLowerCase();
  const template = CommonProviderSettings[domain] || {};

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
  }

  return Object.assign({}, existingAccountInfo, defaults);
}
