import {logIfDebug} from './helpers';

const blacklistExpressions = {
  urls: [
    /www\.roomster\.com/,
    /trulia\.com/,
    /hackerrank\.com/,
    /www\.apartmentlist\.com/,
    /\/wf\/click\?upn=/,
    /timbuk2\.com/,
    /perch-email\.closely\.com/,
    /aore\.memberclicks\.net/,
    /www\.cybercoders\.com/,
    /links\.notifications\.soundcloud\.com\/asm\/unsubscribe/,
    /fullcontact\.com/,
    /www\.facebook\.com/,
    /ke\.am\//,
    /email\.newyorktimes\.com/,
    /github\.com/,
  ],
  emails: [
    /@idearium.activehosted.com/,
    /sympa@/,
    /@blancmedia\.activehosted\.com/,
    /@bounce/,
    /unsubscribe@mail\.notifications\.soundcloud\.com/,
  ],
}

// Takes an array of regular expressions and compares against a target string
function _onBlacklist(regexps, target) {
  for (const re of regexps) {
    if (re.test(target)) {
      logIfDebug(`Found ${target} on blacklist with ${re}`);
      return true;
    }
  }
  return false;
}

// Electron has Jquery and other limitations that block certain known URLs
export function electronCantOpen(url) {
  return _onBlacklist(blacklistExpressions.urls, url);
}

// Some emails fail and are ignored in favor of other links:
export function blacklistedEmail(email) {
  return _onBlacklist(blacklistExpressions.emails, email);
}
