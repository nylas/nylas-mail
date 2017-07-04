import { spawn } from 'child_process';
import path from 'path';

const LocalizedErrorStrings = {
  ErrorConnection: "Connection Error",
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

export default class MailsyncProcess {
  constructor(mode, account, resourcePath) {
    this.mode = mode;
    this.account = account;
    this.binaryPath = path.join(resourcePath, 'MailSync');
  }

  _spawnProcess() {
    const sync = spawn(this.binaryPath, [`--mode`, this.mode]);
    if (this.account) {
      sync.stdout.once('data', () => {
        sync.stdin.write(`${JSON.stringify(this.account)}\n`);
      });
    }
    return sync;
  }

  migrate() {
    return new Promise((resolve, reject) => {
      const sync = this._spawnProcess();
      let buffer = Buffer.from([]);
      sync.stdout.on('data', (data) => {
        buffer += data;
      });
      sync.stderr.on('data', (data) => {
        buffer += data;
      });
      sync.on('error', (err) => {
        reject(err, buffer);
      });
      sync.on('close', (code) => {
        try {
          const lastLine = buffer.toString('UTF-8').split('\n').pop();
          const response = JSON.parse(lastLine);
          if (code === 0) {
            resolve(response);
          } else {
            reject(new Error(LocalizedErrorStrings[response.error]))
          }
        } catch (err) {
          reject(err);
        }
      });
    });
  }

  test() {
    return new Promise((resolve, reject) => {
      const sync = this._spawnProcess();
      let buffer = Buffer.from([]);
      sync.stdout.on('data', (data) => {
        buffer += data;
      });
      sync.stderr.on('data', (data) => {
        buffer += data;
      });
      sync.on('error', (err) => {
        reject(err, buffer);
      });
      sync.on('close', (code) => {
        try {
          const lastLine = buffer.toString('UTF-8').split('\n').pop();
          const response = JSON.parse(lastLine);
          if (code === 0) {
            resolve(response);
          } else {
            reject(new Error(LocalizedErrorStrings[response.error]))
          }
        } catch (err) {
          reject(err);
        }
      });
    });
  }
}
