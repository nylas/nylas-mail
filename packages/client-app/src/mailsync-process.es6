/* eslint global-require: 0 */

/*
Warning! This file is imported from the main process as well as the renderer process
*/
import { spawn } from 'child_process';
import path from 'path';
import { EventEmitter } from 'events';

let Utils = null;

const LocalizedErrorStrings = {
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
};

export default class MailsyncProcess extends EventEmitter {
  constructor({configDirPath, resourcePath}, account, identity) {
    super();
    this.configDirPath = configDirPath;
    this.account = account;
    this.identity = identity;
    this.binaryPath = path.join(resourcePath, 'MailSync').replace('app.asar', 'app.asar.unpacked');
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
        this._proc.stdin.write(`${JSON.stringify(this.account)}\n`);
        this._proc.stdin.write(`${JSON.stringify(this.identity)}\n`);
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
        console.log(`SyncWorker exited mode ${mode} with code ${code}`);
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
    this._proc.kill();
  }

  sync() {
    this._spawnProcess('sync');
    let buffer = "";
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
      console.log(`Sync worker wrote to stderr: ${data.toString()}`);
    });
    this._proc.on('error', (err) => {
      console.log(`Sync worker exited with ${err}`);
      this.emit('error', err);
    });
    this._proc.on('close', (code) => {
      this.emit('close', code);
    });
  }

  sendMessage(json) {
    if (!Utils) { Utils = require('nylas-exports').Utils; }

    const msg = `${JSON.stringify(json)}\n`;
    const contentBuffer = Buffer.from(msg);
    this._proc.stdin.write(contentBuffer);
  }

  migrate() {
    return this._spawnAndWait('migrate');
  }

  test() {
    return this._spawnAndWait('test');
  }
}
