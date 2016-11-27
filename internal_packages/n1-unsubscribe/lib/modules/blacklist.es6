const fs = require('fs-extra');
const util = require('./util');
const blacklistExpressions = fs.readJsonSync(`${__dirname}/blacklistExpressions.json`);

module.exports = {
  // Takes an array of regular expressions and compares against a target string
  regexpcompare(regexps, target) {
    for (let i = 0; i < regexps.length; i += 1) {
      const re = new RegExp(regexps[i]);
      if (re.test(target)) {
        util.logIfDebug(`Found ${target} on blacklist with ${re}`);
        return true;
      }
    }
    return false;
  },

  // Determine if the link can be opened in the electron browser or if it
  // should be directed to the default browser
  checkLinkBlacklist(url) {
    const regexps = blacklistExpressions.browser;
    return this.regexpcompare(regexps, url);
  },

  // Check if the unsubscribe email is known to fail
  checkEmailBlacklist(email) {
    const regexps = blacklistExpressions.emails;
    if (/\?/.test(email)) {
      util.warnIfDebug('Parsing complicated mailto: URL\'s is not yet' +
        ' supported by N1-Unsibscribe:' +
        `\n${email}`);
    }
    return this.regexpcompare(regexps, email) || /\?/.test(email);
  },
}
