module.exports = {
  logIfDebug: (message) => {
    if (NylasEnv.config.get("unsubscribe.debug")) {
      console.debug(message);
    }
  },

  shortenURL(url) {
    // modified from: http://stackoverflow.com/a/26766402/3219667
    const regex = /^([^:/?#]+:?\/\/([^/?#]*))/i;
    const disURL = regex.exec(url)[0];
    return `${disURL}/...`;
  },

  interpretEmail(emailAddress) {
    let subject = 'Unsubscribe';
    let body = 'This is an automated unsubscription request. ' +
      'Please remove the sender of this email from all email lists.';
    // Find if the email has custom components and update returned items:
    const components = emailAddress.split('?');
    for (const component of components) {
      const values = component.split('=');
      const type = values[0];
      if (values.length < 2) {
        NylasEnv.reportError(new Error('Invalid component from unsubscribe ' +
          `email: ${component} of ${emailAddress}`));
      } else if (type === 'subject') {
        subject = values[1];
      } else if (type === 'body') {
        body = values[1];
      } else {
        console.debug(`Unknown component: ${type} = ${values[1]}`);
      }
    }
    const address = components[0];
    return { subject, body, address };
  },

  // TODO: Some kind of native N1 confirmation
  userAlert(message) {
    return confirm(message)
  },
}
