const helpers = require('./helpers');

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
    "sympa@",
    "sympa@lists\\.eng\\.umd\\.edu",
    "@blancmedia\\.activehosted\\.com",
    "@bounce",
    "unsubscribe@mail\\.notifications\\.soundcloud\\.com",
  ],
}

module.exports = {
  // Takes an array of regular expressions and compares against a target string
  onBlacklist(regexps, target) {
    for (let i = 0; i < regexps.length; i += 1) {
      const re = new RegExp(regexps[i]);
      if (re.test(target)) {
        console.debug(helpers.debug(), `Found ${target} on blacklist with ${re}`);
        return true;
      }
    }
    return false;
  },

  // Electron has Jquery and other limitations that block certain known URLs
  electronCanOpen(url) {
    return !this.onBlacklist(blacklistExpressions.urls, url);
  },

  // Some emails fail and are ignored in favor of other links:
  blacklistedEmail(email) {
    return this.onBlacklist(blacklistExpressions.emails, email);
  },
}
