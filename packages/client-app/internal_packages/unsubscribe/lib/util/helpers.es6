import {parse} from "mailto-parser";
import {remote} from 'electron';

const MAX_USERNAME_LENGTH = 15;
const MAX_DOMAIN_LENGTH = 25;

export function logIfDebug(message) {
  console.debug(NylasEnv.config.settings.devMode, message);
}

export function shortenURL(url) {
  const regex = /^(?:[^:/?#]+:?\/\/([^/?#]*))/i;
  const disURL = regex.exec(url)[1];
  return `${disURL}/...`;
}

export const defaultBody = 'This is an automated unsubscription request. ' +
  'Please remove the sender of this email from all email lists.'

export function interpretEmail(emailAddress) {
  const parsedEmail = parse(emailAddress);
  const email = {
    body: parsedEmail.attributeKey.body || defaultBody,
    subject: parsedEmail.attributeKey.subject || "Unsubscribe",
    to: [{
      email: parsedEmail.to,
    }],
  }
  if (parsedEmail.attributeKey.cc) {
    email.cc = [{
      email: parsedEmail.attributeKey.cc,
    }];
  }
  if (parsedEmail.attributeKey.bcc) {
    email.bcc = [{
      email: parsedEmail.attributeKey.bcc,
    }];
  }
  return email;
}

export function shortenEmail(email) {
  const address = interpretEmail(email).to[0].email;
  const parts = address.split('@', 2);
  const shortUsername = parts[0].length > MAX_USERNAME_LENGTH ? `${parts[0].substring(0, MAX_USERNAME_LENGTH - 3)}...` : parts[0];
  const shortDomain = parts[1].length > MAX_DOMAIN_LENGTH ? `${parts[1].substring(0, MAX_DOMAIN_LENGTH - 3)}...` : parts[1];
  return `${shortUsername}@${shortDomain}`;
}

export function userConfirm(message, detail) {
  const chosen = remote.dialog.showMessageBox(NylasEnv.getCurrentWindow(), {
    type: 'info',
    message: message,
    detail: detail,
    buttons: ['Cancel', 'Unsubscribe'],
  });

  return chosen === 1;
}
