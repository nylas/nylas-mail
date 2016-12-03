const blacklist = require('./blacklist');

module.exports = {
  // Examine the email headers for the list-unsubscribe header
  parseHeadersForLinks(headers) {
    const unsubscribeLinks = [];
    if (headers) {
      const headersLU = headers['list-unsubscribe'];
      if (headersLU && typeof headersLU === 'string') {
        const rawLinks = headersLU.split(/,/g);
        rawLinks.forEach((link) => {
          const trimmedLink = link.trim();
          if (/mailto.*/g.test(link)) {
            if (blacklist.checkEmailBlacklist(trimmedLink) === false) {
              unsubscribeLinks.push(trimmedLink.substring(1, trimmedLink.length - 1));
            }
          } else {
            unsubscribeLinks.push(trimmedLink.substring(1, trimmedLink.length - 1));
          }
        });
      }
    }
    return unsubscribeLinks;
  },
}
