module.exports = {
  logIfDebug: (message) => {
    if (NylasEnv.inDevMode() === true && process.env.N1_UNSUBSCRIBE_DEBUG === 'true') {
      console.log(message);
    }
  },
  warnIfDebug: (message) => {
    if (NylasEnv.inDevMode() === true && process.env.N1_UNSUBSCRIBE_DEBUG === 'true') {
      console.warn(message);
    }
  },
  logError: (message) => {
    if (NylasEnv.inDevMode() === true) {
      console.error(message);
    }
  },

  shortenURL(url) {
    // modified from: http://stackoverflow.com/a/26766402/3219667
    const regex = /^([^:/?#]+:?\/\/([^/?#]*))/i;
    const disURL = regex.exec(url)[0];
    return `${disURL}/...`;
  },

  // To be replaced with a better interface
  userAlert(message) {
    return confirm(message)
  },
}
