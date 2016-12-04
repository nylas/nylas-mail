const {
  Actions,
  TaskFactory,
  FocusedPerspectiveStore,
  NylasAPI,
} = require('nylas-exports');
const NylasStore = require('nylas-store');
const MailParser = require('mailparser').MailParser;
const BrowserWindow = require('electron').remote.BrowserWindow;
const open = require('open');
const _ = require('underscore');
const util = require('./modules/util');
const blacklist = require('./modules/blacklist');
const emailBodyParser = require('./modules/emailBodyParser');
const emailHeaderParser = require('./modules/emailHeaderParser');
const ThreadConditionType = require('./enum/threadConditionType');


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
        util.logError('Can not unsubscribe for some reason. See this.links below:');
        util.logError(this.links);
      }
    }
  }

  // Initializes the _links array by analyzing the headers and body of the current email thread
  loadLinks() {
    this.loadMessagesViaAPI((error, email) => {
      if (!error) {
        const confirmText = `Are you sure that you want to unsubscribe?`;
        this.isForwarded = this.thread.subject.match(/^Fwd: /i);
        this.confirmText = this.isForwarded ? `The email was forwarded. ${confirmText}` : confirmText;

        // Find and concatenate links:
        const headerLinks = emailHeaderParser.parseHeadersForLinks(email.headers);
        let bodyLinks = []
        if (email.html) {
          bodyLinks = emailBodyParser.parseBodyHTMLForLinks(email.html);
        } else if (email.text) {
          bodyLinks = emailBodyParser.parseBodyTextForLinks(email.text);
        }
        this.links = this.parseLinksForTypes(headerLinks.concat(bodyLinks));
        this.threadState.hasLinks = (this.links.length > 0);
        this.threadState.condition = this.threadState.hasLinks ? ThreadConditionType.DONE : ThreadConditionType.DISABLED;
        // Output troubleshooting info if in debug mode:
        if (this.threadState.hasLinks) {
          util.logIfDebug(`Found links for: "${this.thread.subject}"`);
          util.logIfDebug({headerLinks, bodyLinks});
        } else {
          util.logIfDebug(`Found no links for: "${this.thread.subject}"`);
        }
      } else if (error === 'sentMail') {
        util.logIfDebug(`Can not parse "${this.thread.subject}" because it was sent from this account`);
        this.threadState.condition = ThreadConditionType.DISABLED;
      } else if (error === 'noEmail') {
        util.logError(`Can not parse an email for an unknown reason. See error message below:`);
        util.logError(email);
        this.threadState.condition = ThreadConditionType.ERRORED;
      } else {
        util.logError(`\n--Error in querying message: ${this.thread.subject}--\n`);
        util.logError(error);
        util.logError(email);
        this.threadState.condition = ThreadConditionType.ERRORED;
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
    if (url === undefined) {
      // FIXME: Gmail Security Alert Email has undefined emails from body?
      NylasEnv.reportError(new Error("No URL to unsubscribe from"));
    }
    util.logError(url);
    url = url.replace(/^ttp:/, 'http:');
    const disURL = util.shortenURL(url);
    if ((!this.isForwarded && process.env.N1_UNSUBSCRIBE_CONFIRM_BROWSER === 'false') ||
      util.userAlert(`${this.confirmText}\nA browser will be opened at:\n\n${disURL}`)) {
      util.logIfDebug(`Opening a browser window to:\n${url}`);
      if (blacklist.checkLinkBlacklist(url) ||
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

  // Takes a String email address and sends an email to it in order to unsubscribe from the list
  unsubscribeViaMail(emailAddress, callback) {
    if (emailAddress) {
      if ((!this.isForwarded && process.env.N1_UNSUBSCRIBE_CONFIRM_EMAIL === 'false') ||
        util.userAlert(`${this.confirmText}\nAn email will be sent to:\n${emailAddress}`)) {
        util.logIfDebug(`Sending an unsubscription email to:\n${emailAddress}`);
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
            // TODO: Do nothing - for now
          },
          error: (error) => {
            util.logError(error);
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
}

module.exports = ThreadUnsubscribeStore;
