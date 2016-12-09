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

  // TODO: Some kind of native N1 confirmation
  userAlert(message) {
    return confirm(message)
  },
}
