const blacklistExpressions = {
  urls: [
    "www\\.roomster\\.com",
    "trulia\\.com",
    "hackerrank\\.com",
    "www\\.apartmentlist\\.com",
    "\\/wf\\/click\\?upn='",
    "timbuk2\\.com",
    "perch-email\\.closely\\.com",
    "aore\\.memberclicks\\.net",
    "www\\.cybercoders\\.com",
    "links\\.notifications\\.soundcloud\\.com\\/asm\\/unsubscribe",
    "fullcontact\\.com",
    "www\\.facebook\\.com",
    "ke\\.am\\/",
    "email\\.newyorktimes\\.com",
    "github\\.com",
  ],
  emails: [
    "@idearium.activehosted.com",
    "sympa@lists\\.eng\\.umd\\.edu",
    "sympa@",
    "@blancmedia\\.activehosted\\.com",
    "@bounce",
    "unsubscribe@mail\\.notifications\\.soundcloud\\.com",
  ],
}

module.exports = {
  // Takes an array of regular expressions and compares against a target string
  regexpcompare(regexps, target) {
    for (let i = 0; i < regexps.length; i += 1) {
      const re = new RegExp(regexps[i]);
      if (re.test(target)) {
        console.debug(NylasEnv.config.get('unsubscribe.debug'), `Found ${target} on blacklist with ${re}`);
        return true;
      }
    }
    return false;
  },

  // Determine if the link can be opened in the electron browser or if it
  // should be directed to the default browser
  containsURL(url) {
    return this.regexpcompare(blacklistExpressions.urls, url);
  },

  // Check if the unsubscribe email is known to fail
  containsEmail(email) {
    return this.regexpcompare(blacklistExpressions.emails, email) || /\?/.test(email);
  },
}
