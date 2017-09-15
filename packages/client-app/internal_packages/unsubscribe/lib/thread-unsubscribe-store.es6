import {
  Actions,
  TaskFactory,
  FocusedPerspectiveStore,
  NylasAPI,
  NylasAPIRequest,
} from 'nylas-exports';
import NylasStore from 'nylas-store';
import {MailParser} from 'mailparser';
import {remote} from 'electron';
import open from 'open';
import _ from 'underscore';
import {logIfDebug, shortenURL, shortenEmail, interpretEmail, userConfirm} from './util/helpers';
import {electronCantOpen} from './util/blacklist';
import EmailParser from './util/email-parser';
import ThreadConditionType from './enum/threadConditionType';

export default class ThreadUnsubscribeStore extends NylasStore {
  constructor(thread) {
    super();
    this.settings = NylasEnv.config.get("unsubscribe");

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
      this._loadLinks();
    }
  }

  _triggerUpdate() {
    this.trigger(this.threadState);
  }

  unsubscribe() {
    if (this.parser && this.parser.canUnsubscribe()) {
      const unsubscribeHandler = (error, unsubscribed) => {
        if (error) {
          this.threadState.condition = ThreadConditionType.ERRORED;
          NylasEnv.reportError(error, this);
        } else if (unsubscribed) {
          this._moveThread();
          this.threadState.condition = ThreadConditionType.UNSUBSCRIBED;
        }
        this._triggerUpdate();
      };

      if (this.parser.emails.length > 0) {
        this._unsubscribeViaMail(this.parser.emails[0], unsubscribeHandler);
      } else {
        this._unsubscribeViaBrowser(this.parser.urls[0], unsubscribeHandler);
      }
    }
  }

  _loadLinks() {
    this._loadMessagesViaAPI((error, email) => {
      if (error) {
        this.threadState.condition = ThreadConditionType.ERRORED;
        NylasEnv.reportError(error, this);
      } else if (email) {
        const confirmText = "Are you sure that you want to unsubscribe?";
        this.isForwarded = this.thread.subject.match(/^Fwd: /i);
        this.confirmText = this.isForwarded ? `The email was forwarded. ${confirmText}` : confirmText;

        this.parser = new EmailParser(email.headers, email.html, email.text);
        this.threadState.condition = this.parser.canUnsubscribe() ? ThreadConditionType.READY : ThreadConditionType.DISABLED;
        // Output troubleshooting info
        logIfDebug(`Found ${(this.parser.canUnsubscribe() ? "" : "no ")}links for: "${this.thread.subject}"`);
        logIfDebug(this.parser);
      } else {
        this.threadState.condition = ThreadConditionType.DISABLED;
      }
      this._triggerUpdate();
    });
  }

  _loadMessagesViaAPI(callback) {
    if (this.messages && this.messages.length > 0) {
      if (this.messages[0].draft || (this.messages[0].categories &&
        _.some(this.messages[0].categories, _.matcher({displayName: "Sent Mail"})))) {
        // Can't unsubscribe from draft or sent emails
        callback(null, null);
      } else {
        // Fetch the email contents to parse for unsubscribe links
        // NOTE: This will only make a request for the first email message in the thread,
        // instead of all messages based on the assumption that the first email will have
        // an unsubscribe link iff you can unsubscribe from that thread.
        const messagePath = `/messages/${this.messages[0].id}`;
        new NylasAPIRequest({
          api: NylasAPI,
          options: {
            accountId: this.thread.accountId,
            path: messagePath,
            headers: {Accept: "message/rfc822"},
            json: false,
          },
        })
        .run()
        .then((rawEmail) => {
          const mailparser = new MailParser();
          mailparser.on('end', (parsedEmail) => {
            callback(null, parsedEmail);
          });
          mailparser.write(rawEmail);
          mailparser.end();
        })
        .catch((err) => {
          callback(err)
        });
      }
    } else {
      callback(new Error('No messages found to parse for unsubscribe links.'));
    }
  }

  _unsubscribeViaBrowser(url, callback) {
    if ((!this.isForwarded && !this.settings.confirmForBrowser) ||
      userConfirm(this.confirmText, `A browser will be opened at: ${shortenURL(url)}`)) {
      logIfDebug(`Opening a browser window to:\n${url}`);
      if (this.settings.defaultBrowser === "native" || electronCantOpen(url)) {
        open(url);
        callback(null, /* unsubscribed=*/true);
      } else {
        const browserWindow = new remote.BrowserWindow({
          'web-preferences': { 'web-security': false, 'nodeIntegration': false },
          'width': 1000,
          'height': 800,
          'center': true,
          "alwaysOnTop": true,
        });
        browserWindow.on('closed', () => {
          callback(null, /* unsubscribed=*/true);
        });
        browserWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription) => {
          // Unable to load this URL in a browser window. Redirect to a native browser.
          logIfDebug(`Failed to open URL in browser window: ${errorCode} ${errorDescription}`);
          browserWindow.destroy();
          open(url);
        });
        browserWindow.loadURL(url);
        browserWindow.show();
      }
    } else {
      callback(null, /* unsubscribed=*/false);
    }
  }

  _unsubscribeViaMail(emailAddress, callback) {
    if (emailAddress) {
      if ((!this.isForwarded && !this.settings.confirmForEmail) ||
        userConfirm(this.confirmText, `An email will be sent to:\n${shortenEmail(emailAddress)}`)) {
        logIfDebug(`Sending an email to: ${emailAddress}`);
        new NylasAPIRequest({
          api: NylasAPI,
          options: {
            accountId: this.thread.accountId,
            path: '/send',
            method: 'POST',
            body: interpretEmail(emailAddress),
          },
        })
        .run()
        .catch((err) => {
          NylasEnv.reportError(err, this)
        });
        // Send the callback now so that emails are moved immediately
        // instead of waiting for the email to be sent.
        callback(null, /* unsubscribed= */true);
      } else {
        callback(null, /* unsubscribed= */false);
      }
    } else {
      callback(new Error(`Invalid email address (${emailAddress})`), /* unsubscribed= */false);
    }
  }

  _moveThread() {
    switch (this.settings.handleThreads) {
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
