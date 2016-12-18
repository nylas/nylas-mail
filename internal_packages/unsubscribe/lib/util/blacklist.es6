import _ from 'underscore';

const blacklistExpressions = {
  // Electron has Jquery and other limitations that block certain known URLs
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
  // Some emails are known to fail or require a custom body message
  emails: [
    /@idearium.activehosted.com/,
    /sympa@/,
    /@blancmedia\.activehosted\.com/,
    /@bounce/,
    /unsubscribe@mail\.notifications\.soundcloud\.com/,
  ],
}

export function electronCantOpen(url) {
  return _.some(blacklistExpressions.urls, (re) => re.test(url));
}

export function blacklistedEmail(email) {
  return _.some(blacklistExpressions.emails, (re) => re.test(email));
}
