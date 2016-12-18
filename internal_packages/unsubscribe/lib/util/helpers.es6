import {parse} from "mailto-parser";
import {remote} from 'electron';

export function logIfDebug(message) {
  console.debug(NylasEnv.config.settings.devMode, message);
}

export function shortenURL(url) {
  // modified from: http://stackoverflow.com/a/26766402/3219667
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
  const parts = address.split('@', 1);
  const shortUsername = parts[0].length > 10 ? `${parts[0].substring(0, 7)}...` : parts[0];
  const shortDomain = parts[1].length > 10 ? `${parts[1].substring(0, 7)}...` : parts[1];
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
