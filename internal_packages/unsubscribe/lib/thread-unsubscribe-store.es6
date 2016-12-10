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
const helpers = require('./util/helpers');
const blacklist = require('./util/blacklist');
const EmailParser = require('./util/email-parser');
const ThreadConditionType = require('./enum/threadConditionType');


class ThreadUnsubscribeStore extends NylasStore {
  constructor(thread) {
    super();

    if (!thread) {
      NylasEnv.reportError(new Error("Invalid thread object"));
      this.threadState = {
        id: null,
        condition: ThreadConditionType.ERRORED,
      }
    } else {
      this.thread = thread;
      this.threadState = {
        id: this.thread.id,
        condition: ThreadConditionType.LOADING,
      }
      this.messages = this.thread.__messages;
      this.loadLinks();
    }
  }

  triggerUpdate() {
    this.trigger(this.threadState);
  }

  // Opens the unsubscribe link to unsubscribe the user
  // The optional callback returns: (Error, Boolean indicating whether it was a success)
  unsubscribe() {
    if (this.parser && this.parser.canUnsubscribe()) {
      const unsubscribeHandler = (error, unsubscribed) => {
        if (error) {
          this.threadState.condition = ThreadConditionType.ERRORED;
          NylasEnv.reportError(error, this);
        } else if (unsubscribed) {
          this.moveThread();
          this.threadState.condition = ThreadConditionType.UNSUBSCRIBED;
        }
        this.triggerUpdate();
      };

      if (this.parser.emails.length > 0) {
        this.unsubscribeViaMail(this.parser.emails[0], unsubscribeHandler);
      } else {
        this.unsubscribeViaBrowser(this.parser.urls[0], unsubscribeHandler);
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
        this.parser = new EmailParser(email.headers, email.html, email.text);
        this.threadState.condition = this.parser.canUnsubscribe() ? ThreadConditionType.READY : ThreadConditionType.DISABLED;
        // Output troubleshooting info if in debug mode:
        helpers.logIfDebug(`Found ${(this.parser.canUnsubscribe() ? "" : "no ")}links for: "${this.thread.subject}"`);
        helpers.logIfDebug(this.parser);
      } else {
        this.threadState.condition = ThreadConditionType.ERRORED;
        NylasEnv.reportError(error, this);
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

  // Takes a String URL to later open a URL
  unsubscribeViaBrowser(rawURL, callback) {
    let url = rawURL
    url = url.replace(/^ttp:/, 'http:');
    const disURL = helpers.shortenURL(url);
    if (!this.isForwarded && (!NylasEnv.config.get("unsubscribe.confirmForBrowser") ||
      helpers.userAlert(`${this.confirmText}\nA browser will be opened at:\n\n${disURL}`))) {
      helpers.logIfDebug(`Opening a browser window to:\n${url}`);
      if (NylasEnv.config.get("unsubscribe.useNativeBrowser") || blacklist.electronCanOpen(url)) {
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
      if (!this.isForwarded && (!NylasEnv.config.get("unsubscribe.confirmForEmail") ||
        helpers.userAlert(`${this.confirmText}\nAn email will be sent to:\n${emailAddress}`))) {
        helpers.logIfDebug(`Sending an unsubscription email to:\n${emailAddress}`);
        const email = helpers.interpretEmail(emailAddress)
        NylasAPI.makeRequest({
          path: '/send',
          method: 'POST',
          accountId: this.thread.accountId,
          body: {
            body: email.body,
            subject: email.subject,
            to: [{
              email: email.address,
            }],
          },
          success: () => {
            // TODO: Do nothing - for now
          },
          error: (error) => {
            NylasEnv.reportError(error, this);
          },
        });
        // Temporary solution right now so that emails are trashed immediately
        // instead of waiting for the email to be sent.
        callback(null, /* unsubscribed= */true);
      } else {
        callback(null, /* unsubscribed= */false);
      }
    } else {
      callback(new Error(`Invalid email address (${emailAddress})`), /* unsubscribed= */false);
    }
  }

  // Move the given thread to the trash or archive
  moveThread() {
    switch (NylasEnv.config.get("unsubscribe.handleThreads")) {
      case "trash":
        if (FocusedPerspectiveStore.current().canTrashThreads([this.thread])) {
          const tasks = TaskFactory.tasksForMovingToTrash({
            threads: [this.thread],
            fromPerspective: FocusedPerspectiveStore.current(),
          });
          Actions.queueTasks(tasks);
        }
        break;
      case "archive":
        if (FocusedPerspectiveStore.current().canArchiveThreads([this.thread])) {
          const tasks = TaskFactory.tasksForArchiving({
            threads: [this.thread],
            fromPerspective: FocusedPerspectiveStore.current(),
          });
          Actions.queueTasks(tasks);
        }
        break;
      default:
        // "none" case -- do not move email
    }
    Actions.popSheet();
  }
}

module.exports = ThreadUnsubscribeStore;
