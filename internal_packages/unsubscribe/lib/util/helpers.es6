const mailto = require("mailto-parser");

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
  const parsedEmail = mailto.parse(emailAddress);
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

// TODO: Some kind of native N1 confirmation
export function userAlert(message) {
  return confirm(message);
}
