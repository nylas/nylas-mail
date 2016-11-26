const {
  Actions,
  TaskFactory,
  FocusedPerspectiveStore,
  NylasAPI,
} = require('nylas-exports');

const NylasStore = require('nylas-store');
const _ = require('underscore');
const fs = require('fs-extra');
const open = require('open');
const cheerio = require('cheerio');
const BrowserWindow = require('electron').remote.BrowserWindow;
const MailParser = require('mailparser').MailParser;
const ThreadConditionType = require(`${__dirname}/enum/threadConditionType`);
const blacklist = fs.readJsonSync(`${__dirname}/blacklist.json`);

class ThreadUnsubscribeStore extends NylasStore {
  constructor(thread) {
    super();

    this.LinkType = {
      EMAIL: 'EMAIL',
      BROWSER: 'BROWSER',
    };

    this.thread = thread;
    this.threadState = {
      id: this.thread.id,
      condition: ThreadConditionType.LOADING,
      hasLinks: false,
    }
    this.messages = this.thread.__messages;
    this.links = [];
    this.loadLinks();
  }

  canUnsubscribe() {
    return this.links.length > 0;
  }

  triggerUpdate() {
    this.trigger(this.threadState);
  }

  // Opens the unsubscribe link to unsubscribe the user
  // The optional callback returns: (Error, Boolean indicating whether it was a success)
  unsubscribe() {
    if (this.canUnsubscribe()) {
      const unsubscribeHandler = (error) => {
        if (!error) {
          this.moveThread();
          this.threadState.condition = ThreadConditionType.UNSUBSCRIBED;
        } else {
          this.threadState.condition = ThreadConditionType.ERRORED;
        }
        this.triggerUpdate();
      };

      // Determine if best to unsubscribe via email or browser:
      if (this.links[0].type === this.LinkType.EMAIL) {
        this.unsubscribeViaMail(this.links[0].link, unsubscribeHandler);
      } else if (this.links.length > 0) {
        this.unsubscribeViaBrowser(this.links[0].link, unsubscribeHandler);
      } else {
        this.threadState.condition = ThreadConditionType.ERRORED;
        console.error('Can not unsubscribe for some reason. See this.links below:');
        console.error(this.links);
      }
    }
  }

  // Initializes the _links array by analyzing the headers and body of the current email thread
  loadLinks() {
    this.loadMessagesViaAPI((error, email) => {
      if (!error) {
        // Take note when asking to unsubscribe later:
        this.isForwarded = this.thread.subject.match(/^Fwd: /i);
        if (this.isForwarded) {
          this.confirmText = `The email was forwarded, are you sure that you` +
            ` want to unsubscribe?`;
        } else {
          this.confirmText = `Are you sure that you want to unsubscribe?`;
        }

        // Find and concatenate links:
        const headerLinks = this.parseHeadersForLinks(email.headers);
        const bodyLinks = this.parseBodyForLinks(email.html);
        this.links = this.parseLinksForTypes(headerLinks.concat(bodyLinks));
        this.threadState.hasLinks = (this.links.length > 0);
        if (this.threadState.hasLinks) {
          this.threadState.condition = ThreadConditionType.DONE;
        } else {
          this.threadState.condition = ThreadConditionType.DISABLED;
        }
        if (NylasEnv.inDevMode() === true && process.env.N1_UNSUBSCRIBE_DEBUG === 'true') {
          if (this.threadState.hasLinks) {
            console.info(`Found links for: "${this.thread.subject}"`);
            console.info({headerLinks, bodyLinks});
          } else {
            console.log(`Found no links for: "${this.thread.subject}"`);
          }
        }
      } else if (error === 'sentMail') {
        console.log(`Can not parse "${this.thread.subject}" because it was sent from this account`);
        this.threadState.condition = ThreadConditionType.DISABLED;
      } else if (error === 'noEmail') {
        console.warn(`Can not parse an email for an unknown reason. See error message below:`);
        console.warn(email);
        this.threadState.condition = ThreadConditionType.ERRORED;
      } else {
        if (NylasEnv.inDevMode() === true) {
          console.warn(`\n--Error in querying message: ${this.thread.subject}--\n`);
          console.warn(error);
          console.warn(email);
        }
        this.threadState.condition = ThreadConditionType.ERRORED;
        this.triggerUpdate();
      }
      this.triggerUpdate();
    });
  }

  // Makes an API request to fetch the data on the
  // NOTE: This will only make a request for the first email message in the thread,
  // instead of all messages based on the assumption that all of the emails in the
  // thread will have the unsubscribe link.
  // Callback: (Error, Parsed email)
  loadMessagesViaAPI(callback) {
    // Ignore any sent messages because they return a 404 error:
    let type = '';
    let sentMail = false;
    if (this.messages !== undefined && this.messages.length > 0) {
      if (this.messages[0] && this.messages[0].categories) {
        _.each(this.messages[0].categories, (category) => {
          type = category.displayName;
          if (type === "Sent Mail") {
            sentMail = true;
          }
        });
      }
      if (sentMail) {
        callback('sentMail', null);
      } else if (this.messages[0].draft) {
        callback(new Error('Draft emails aren\'t parsed for unsubscribe links.'));
      } else if (this.messages.length > 0) {
        const messagePath = `/messages/${this.messages[0].id}`;
        NylasAPI.makeRequest({
          path: messagePath,
          accountId: this.thread.accountId,
          headers: {Accept: "message/rfc822"},
          json: false,
          success: (rawEmail) => {
            const mailparser = new MailParser();
            mailparser.on('end', (parsedEmail) => {
              callback(null, parsedEmail);
            });
            mailparser.write(rawEmail);
            mailparser.end();
          },
          error: (error) => {
            callback(error);
          },
        });
      }
    } else {
      callback('noEmail', new Error('No messages found to parse for unsubscribe links.'));
    }
  }

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
            if (this.checkEmailBlacklist(trimmedLink) === false) {
              unsubscribeLinks.push(trimmedLink.substring(1, trimmedLink.length - 1));
            }
          } else {
            unsubscribeLinks.push(trimmedLink.substring(1, trimmedLink.length - 1));
          }
        });
      }
    }
    return unsubscribeLinks;
  }

  // Parse the HTML within the email body for unsubscribe links
  parseBodyForLinks(emailHTML) {
    const unsubscribeLinks = [];
    if (emailHTML) {
      const $ = cheerio.load(emailHTML);
      let links = _.filter($('a'), emailLink => emailLink.href !== 'blank');
      links = links.concat(this.getLinkedSentences($));
      const regexps = [
        /unsubscribe/gi,
        /Unfollow/gi,
        /opt[ -]{0,2}out/gi,
        /email preferences/gi,
        /subscription/gi,
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

      for (let j = 0; j < links.length; j += 1) {
        const link = links[j];
        for (let i = 0; i < regexps.length; i += 1) {
          const re = regexps[i];
          if (re.test(link.href) || re.test(link.innerText)) {
            unsubscribeLinks.push(link.href);
          }
        }
      }
    }
    return unsubscribeLinks;
  }

  // Given a list of unsubscribe links (Strings)
  // Returns a list of objects with a link and a LinkType
  // The returned list is in the same order as links,
  // except that EMAIL links are pushed to the front.
  parseLinksForTypes(links) {
    const newLinks = _.sortBy(_.map(links, (link) => {
      const type = (/mailto.*/g.test(link) ? this.LinkType.EMAIL : this.LinkType.BROWSER);
      const data = {link, type};
      if (type === this.LinkType.EMAIL) {
        const matches = /mailto:([^?]*)/g.exec(link);
        if (matches && matches.length > 1) {
          data.link = matches[1];
        }
      }
      return data;
    }), (link) => {
      if (link.type === this.LinkType.EMAIL) {
        this.threadState.isEmail = true;
        return 0;
      }
      return 1;
    });
    return newLinks;
  }
  // Takes a String URL to later open a URL
  unsubscribeViaBrowser(rawURL, callback) {
    let url = rawURL
    url = url.replace(/^ttp:/, 'http:');
    const disURL = this.shortenURL(url);
    if ((!this.isForwarded && process.env.N1_UNSUBSCRIBE_CONFIRM_BROWSER === 'false') ||
      confirm(`${this.confirmText}\nA browser will be opened at:\n\n${disURL}`)) {
      if (NylasEnv.inDevMode() === true) {
        console.log(`Opening a browser window to:\n${url}`);
      }

      if (this.checkLinkBlacklist(url) ||
        process.env.N1_UNSUBSCRIBE_USE_BROWSER === 'true') {
        open(url);
        callback(null);
      } else {
        const browserWindow = new BrowserWindow({
          'web-preferences': { 'web-security': false },
          'width': 1000,
          'height': 800,
          'center': true,
        });
        browserWindow.on('closed', () => {
          callback(null, true);
        });
        browserWindow.loadURL(url);
        browserWindow.show();
      }
    }
  }

  // Quick solution to
  shortenURL(url) {
    // modified from: http://stackoverflow.com/a/26766402/3219667
    const regex = /^([^:/?#]+:?\/\/([^/?#]*))/i;
    const disURL = regex.exec(url)[0];
    return `${disURL}/...`;
  }

  // Determine if the link can be opened in the electron browser or if it
  // should be directed to the default browser
  checkLinkBlacklist(url) {
    const regexps = blacklist.browser;
    return this.regexpcompare(regexps, url);
  }

  // Check if the unsubscribe email is known to fail
  checkEmailBlacklist(email) {
    const regexps = blacklist.emails;
    if (/\?/.test(email)) {
      console.warn('Parsing complicated mailto: URL\'s is not yet' +
        ' supported by N1-Unsibscribe:' +
        `\n${email}`);
    }
    return this.regexpcompare(regexps, email) || /\?/.test(email);
  }

  // Takes an array of regular expressions and compares against a target string
  regexpcompare(regexps, target) {
    for (let i = 0; i < regexps.length; i += 1) {
      const re = new RegExp(regexps[i]);
      if (re.test(target)) {
        if (NylasEnv.inDevMode() === true) {
          console.log(`Found ${target} on blacklist with ${re}`);
        }
        return true;
      }
    }
    return false;
  }

  // Takes a String email address and sends an email to it in order to unsubscribe from the list
  unsubscribeViaMail(emailAddress, callback) {
    if (emailAddress) {
      if ((!this.isForwarded && process.env.N1_UNSUBSCRIBE_CONFIRM_EMAIL === 'false') ||
        confirm(`${this.confirmText}\nAn email will be sent to:\n${emailAddress}`)) {
        if (NylasEnv.inDevMode() === true) {
          console.log(`Sending an unsubscription email to:\n${emailAddress}`);
        }

        NylasAPI.makeRequest({
          path: '/send',
          method: 'POST',
          accountId: this.thread.accountId,
          body: {
            body: 'This is an automated unsubscription request. ' +
              'Please remove the sender of this email from all email lists.',
            subject: 'Unsubscribe',
            to: [{
              email: emailAddress,
            }],
          },
          success: () => {
            // Do nothing - for now
          },
          error: (error) => {
            console.error(error);
          },
        });

        // Temporary solution right now so that emails are trashed immediately
        // instead of waiting for the email to be sent.
        callback(null);
      } else {
        callback(new Error('Did not confirm -- do not unsubscribe.'));
      }
    } else {
      callback(new Error(`Invalid email address (${emailAddress})`));
    }
  }

  // Move the given thread to the trash or archive
  moveThread() {
    if (this.thread) {
      if (process.env.N1_UNSUBSCRIBE_THREAD_HANDLING === 'trash') {
        if (FocusedPerspectiveStore.current().canTrashThreads([this.thread])) {
          const tasks = TaskFactory.tasksForMovingToTrash({
            threads: [this.thread],
            fromPerspective: FocusedPerspectiveStore.current(),
          });
          Actions.queueTasks(tasks);
        }
      } else if (process.env.N1_UNSUBSCRIBE_THREAD_HANDLING === 'archive') {
        if (FocusedPerspectiveStore.current().canArchiveThreads([this.thread])) {
          const tasks = TaskFactory.tasksForArchiving({
            threads: [this.thread],
            fromPerspective: FocusedPerspectiveStore.current(),
          });
          Actions.queueTasks(tasks);
        }
      }
      Actions.popSheet();
    }
  }

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
  }
}

module.exports = ThreadUnsubscribeStore;
