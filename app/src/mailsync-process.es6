/* eslint global-require: 0 */

/*
Warning! This file is imported from the main process as well as the renderer process
*/
import { spawn, exec } from 'child_process';
import path from 'path';
import os from 'os';
import { EventEmitter } from 'events';
import fs from 'fs';

let Utils = null;

export const LocalizedErrorStrings = {
  ErrorConnection: "Connection Error - Check that your internet connection is active.",
  ErrorInvalidAccount: "This account is invalid, or does not have an inbox or all folder.",
  ErrorTLSNotAvailable: "TLS Not Available",
  ErrorParse: "Parsing Error",
  ErrorCertificate: "Certificate Error",
  ErrorAuthentication: "Authentication Error - Check your username and password.",
  ErrorGmailIMAPNotEnabled: "Gmail IMAP is not enabled. Visit Gmail settings to turn it on.",
  ErrorGmailExceededBandwidthLimit: "Gmail bandwidth exceeded. Please try again later.",
  ErrorGmailTooManySimultaneousConnections: "There are too many active connections to your Gmail account. Please try again later.",
  ErrorMobileMeMoved: "MobileMe has moved.",
  ErrorYahooUnavailable: "Yahoo is unavailable.",
  ErrorNonExistantFolder: "Sorry, this folder does not exist.",
  ErrorStartTLSNotAvailable: "StartTLS is not available.",
  ErrorGmailApplicationSpecificPasswordRequired: "A Gmail application-specific password is required.",
  ErrorOutlookLoginViaWebBrowser: "The Outlook server said you must sign in via a web browser.",
  ErrorNeedsConnectToWebmail: "The server said you must sign in via your webmail.",
  ErrorNoValidServerFound: "No valid server found.",
  ErrorAuthenticationRequired: "Authentication required.",

  // sending related
  ErrorSendMessageNotAllowed: "Sending is not enabled for this account.",
  ErrorSendMessageIllegalAttachment: "The message contains an illegial attachment that is not allowed by the server.",
  ErrorYahooSendMessageSpamSuspected: "The message has been blocked by Yahoo's outbound spam filter.",
  ErrorYahooSendMessageDailyLimitExceeded: "The message has been blocked by Yahoo - you have exceeded your daily sending limit.",
  ErrorNoSender: "The message has been blocked because no sender is configured.",
};

export default class MailsyncProcess extends EventEmitter {
  constructor({configDirPath, resourcePath}, identity, account) {
    super();
    this.configDirPath = configDirPath;
    this.account = account;
    this.identity = identity;
    this.binaryPath = path.join(resourcePath, 'mailsync').replace('app.asar', 'app.asar.unpacked');
    this._proc = null;
  }

  _spawnProcess(mode) {
    const env = {
      CONFIG_DIR_PATH: this.configDirPath,
      IDENTITY_SERVER: 'unknown',
      ACCOUNTS_SERVER: 'unknown',
    };
    if (process.type === 'renderer') {
      const rootURLForServer = require('./flux/nylas-api-request').rootURLForServer;
      env.IDENTITY_SERVER = rootURLForServer('identity');
      env.ACCOUNTS_SERVER = rootURLForServer('accounts');
    }

    this._proc = spawn(this.binaryPath, [`--mode`, mode], {env});
    if (this.account) {
      this._proc.stdout.once('data', () => {
        this._proc.stdin.write(`${JSON.stringify(this.account)}\n${JSON.stringify(this.identity)}\n`);
      });
    }
  }

  _spawnAndWait(mode) {
    return new Promise((resolve, reject) => {
      this._spawnProcess(mode);
      let buffer = Buffer.from([]);
      this._proc.stdout.on('data', (data) => {
        buffer += data;
      });
      this._proc.stderr.on('data', (data) => {
        buffer += data;
      });
      this._proc.on('error', (err) => {
        reject(err);
      });
      this._proc.on('close', (code) => {
        try {
          const lastLine = buffer.toString('UTF-8').split('\n').pop();
          const response = JSON.parse(lastLine);
          if (code === 0) {
            resolve(response);
          } else {
            reject(new Error(LocalizedErrorStrings[response.error] || response.error))
          }
        } catch (err) {
          reject(new Error(buffer.toString()));
        }
      });
    });
  }

  kill() {
    console.warn("Terminating mailsync...");
    this._proc.kill();
  }

  sync() {
    this._spawnProcess('sync');
    let buffer = "";
    let errBuffer = null;

    this._proc.stdout.on('data', (data) => {
      const added = data.toString();
      buffer += added;

      if (added.indexOf('\n') !== -1) {
        const msgs = buffer.split('\n');
        buffer = msgs.pop();
        this.emit('deltas', msgs);
      }
    });
    this._proc.stderr.on('data', (data) => {
      errBuffer += data.toString();
    });
    this._proc.on('error', (err) => {
      console.log(`Sync worker exited with ${err}`);
      this.emit('error', err);
    });
    this._proc.on('close', (code) => {
      let error = null;

      if (buffer.length) {
        let lastJSON = null;
        try {
          lastJSON = JSON.parse(buffer);
        } finally {
          if (lastJSON && lastJSON.error) {
            error = new Error(lastJSON.error);
          } else {
            this.emit('deltas', buffer);
          }
        }
      }

      if (errBuffer) {
        error = new Error(errBuffer);
      }

      this.emit('close', {code, error, signal: this._proc.signalCode});
    });
  }

  sendMessage(json) {
    if (!Utils) { Utils = require('nylas-exports').Utils; }
    console.log(`Sending to mailsync ${this.account.id}`, json);
    const msg = `${JSON.stringify(json)}\n`;
    this._proc.stdin.write(msg, 'UTF8');
  }

  migrate() {
    return this._spawnAndWait('migrate');
  }

  test() {
    return this._spawnAndWait('test');
  }

  attachToXcode() {
    const tmppath = path.join(os.tmpdir(), 'attach.applescript');
    fs.writeFileSync(tmppath, `
tell application "Xcode"
  activate
end tell

tell application "System Events"
  tell application process "Xcode"
    click (menu item "Attach to Process by PID or Name…" of menu 1 of menu bar item "Debug" of menu bar 1)
  end tell
  tell application process "Xcode"
    set value of text field 1 of sheet 1 of window 1 to "${this._proc.pid}"
  end tell
  delay 0.5
  tell application process "Xcode"
    click button "Attach" of sheet 1 of window 1
  end tell
  
end tell
    `);
    exec(`osascript ${tmppath}`);
  }
}
