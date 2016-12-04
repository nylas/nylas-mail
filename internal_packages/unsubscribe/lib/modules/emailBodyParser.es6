const _ = require('underscore');
const cheerio = require('cheerio');

const regexps = [
  /unsubscribe/gi,
  /unfollow/gi,
  /opt[ -]{0,2}out/gi,
  /email preferences/gi,
  /[^/]subscription/gi,
  /notification settings/gi,
  // Danish
  /afmeld/gi,
  /afmelden/gi,
  /af te melden voor/gi,
  // Spanish
  /darse de baja/gi,
  // French
  /désabonnement/gi,
  /désinscrire/gi,
  /désinscription/gi,
  /désabonner/gi,
  /préférences d'email/gi,
  /préférences d'abonnement/gi,
  // Russian - this is probably wrong:
  /отказаться от подписки/gi,
  // Serbian
  /одјавити/gi,
  // Icelandic
  /afskrá/gi,
  // Hebrew
  /לבטל את המנוי/gi,
  // Creole (Haitian)
  /koupe abònman/gi,
  // Chinese (Simplified)
  /退订/gi,
  // Chinese (Traditional)
  /退訂/gi,
  // Arabic
  /إلغاء الاشتراك/gi,
  // Armenian
  /պետք է նախ միանալ/gi,
  // German
  /abmelden/gi,
  /ausschreiben/gi,
  /austragen/gi,
  // Swedish
  /avprenumerera/gi,
  /avregistrera/gi,
  /prenumeration/gi,
  /notisinställningar/gi,
];

module.exports = {
  // Parse the HTML within the email body for unsubscribe links
  parseBodyHTMLForLinks(emailHTML) {
    const unsubscribeLinks = [];
    const $ = cheerio.load(emailHTML);
    let links = _.filter($('a'), emailLink => emailLink.href !== 'blank');
    links = links.concat(this.getLinkedSentences($));
    for (let j = 0; j < links.length; j += 1) {
      const link = links[j];
      for (let i = 0; i < regexps.length; i += 1) {
        const re = regexps[i];
        if (re.test(link.href) || re.test(link.innerText)) {
          unsubscribeLinks.push(link.href);
        }
      }
    }
    return unsubscribeLinks;
  },
  // If just a plain text email, parse the text itself
  parseBodyTextForLinks(emailTEXT) {
    const ext = /[^\s]*/ig
    const unsubscribeLinks = [];
    for (let i = 0; i < regexps.length; i += 1) {
      const re = RegExp(`${ext.source}${regexps[i].source}${ext.source}`, 'ig');
      if (re.test(emailTEXT)) {
        unsubscribeLinks.push(emailTEXT.match(re)[0]);
      }
    }
    return unsubscribeLinks;
  },

  // Takes a parsed DOM (through cheerio) and returns sentences that contain links
  // Good at catching cases such as
  //    "If you would like to unsubscrbe from our emails, please click here."
  // Returns a list of objects, each representing a single link
  // Each object contains an href and innerText property
  getLinkedSentences($) {
    const aParents = [];
    $('a').each((index, aTag) => {
      if (aTag) {
        if (!$(aParents).is(aTag.parent)) {
          aParents.unshift(aTag.parent);
        }
      }
    });

    const linkedSentences = [];
    $(aParents).each((parentIndex, parent) => {
      let link = false;
      let leftoverText = "";
      if (parent) {
        $(parent.children).each((childIndex, child) => {
          if ($(child).is($('a'))) {
            if (link !== false && leftoverText.length > 0) {
              linkedSentences.push({
                href: link,
                innerText: leftoverText,
              });
              leftoverText = "";
            }
            link = $(child).attr('href');
          }
          const text = $(child).text();
          const re = /(.*\.|!|\?\s)|(.*\.|!|\?)$/g;
          if (re.test(text)) {
            const splitup = text.split(re);
            for (let i = 0; i < splitup.length; i += 1) {
              if (splitup[i] !== "" && splitup[i] !== undefined) {
                if (link !== false) {
                  const fullLine = leftoverText + splitup[i];
                  linkedSentences.push({
                    href: link,
                    innerText: fullLine,
                  });
                  link = undefined;
                  leftoverText = "";
                } else {
                  leftoverText += splitup[i];
                }
              }
            }
          } else {
            leftoverText += text;
          }
          leftoverText += " ";
        });
      }
      if (link !== false && leftoverText.length > 0) {
        linkedSentences.push({
          href: link,
          innerText: leftoverText,
        });
      }
    });
    return linkedSentences;
  },
}
