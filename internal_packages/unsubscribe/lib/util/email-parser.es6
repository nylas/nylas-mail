import cheerio from 'cheerio';
import {blacklistedEmail} from './blacklist';

const regexps = [
  // English
  /unsubscribe/gi,
  /unfollow/gi,
  /opt[ -]{0,2}out/gi,
  /email preferences/gi,
  /subscription/gi,
  /notification settings/gi,
  /Remove yourself from this mailing/gi,
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

export default class EmailParser {
  constructor(headers, html, text) {
    this.emails = [];
    this.urls = [];
    this.__headers(headers);
    this.__html(html);
    this.__text(text);
  }

  canUnsubscribe() {
    return this.emails.length > 0 || this.urls.length > 0;
  }

  __headers(headers) {
    if (headers) {
      const unsubHeader = headers['list-unsubscribe'];
      if (unsubHeader && typeof unsubHeader === 'string') {
        unsubHeader.split(',').forEach((link) => {
          this.__addLink(link.trim().replace(/^<|>$/g, ''));
        });
      }
    }
  }

  __html(html) {
    if (html) {
      const $ = cheerio.load(html);
      const links = this.__getLinks($);

      for (const link of links) {
        for (const re of regexps) {
          if (re.test(link.href) || re.test(link.innerText)) {
            this.__addLink(link.href);
          }
        }
      }
    }
  }

  __text(text) {
    if (text) {
      const ext = /[^\s]*/ig;
      for (let i = 0; i < regexps.length; i += 1) {
        const re = RegExp(`${ext.source}${regexps[i].source}${ext.source}`, 'ig');
        const matcher = text.match(re);
        if (matcher) {
          this.__addLink(matcher[0].replace(/(?:\.|!)$/g, ''));
        }
      }
    }
  }

  __addLink(link) {
    if (/mailto:[^>]*/g.test(link)) {
      if (!blacklistedEmail(link)) {
        this.emails.push(link);
      }
    } else if (/https?:.*/g.test(link)) {
      this.urls.push(link);
    }
  }

  // Takes a parsed DOM (through cheerio) and returns links paired with contextual text
  // Good at catching cases such as:
  //    "If you would like to unsubscrbe from our emails, please click here."
  // Returns a list of links as {href, innerText} objects
  __getLinks($) {
    const aParents = [];
    $('a').each((index, aTag) => {
      if (aTag && aTag.parent && !$(aParents).is(aTag.parent)) {
        aParents.unshift(aTag.parent);
      }
    });

    const links = [];
    $(aParents).each((parentIndex, parent) => {
      let link = false;
      let leftoverText = "";
      $(parent.children).each((childIndex, child) => {
        if ($(child).is($('a'))) {
          if (link !== false && leftoverText.length > 0) {
            links.push({
              href: link,
              innerText: leftoverText,
            });
            leftoverText = "";
          }
          link = $(child).attr('href');
        }
        const text = $(child).text();
        const re = /(.*[.!?](?:\s|$))/g;
        if (re.test(text)) {
          const splitup = text.split(re);
          for (let i = 0; i < splitup.length; i += 1) {
            if (splitup[i] !== "" && splitup[i] !== undefined) {
              if (link !== false) {
                const fullLine = leftoverText + splitup[i];
                links.push({
                  href: link,
                  innerText: fullLine,
                });
                link = false;
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
      if (link !== false && leftoverText.length > 0) {
        links.push({
          href: link,
          innerText: leftoverText,
        });
      }
    });
    return links;
  }
}
