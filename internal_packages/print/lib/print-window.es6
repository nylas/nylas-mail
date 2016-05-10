import path from 'path';
import fs from 'fs';
import {remote} from 'electron';

const {app, BrowserWindow} = remote;

export default class PrintWindow {

  constructor({subject, account, participants, styleTags, htmlContent, printMessages}) {
    // This script will create the print prompt when loaded. We can also call
    // print directly from this process, but inside print.js we can make sure to
    // call window.print() after we've cleaned up the dom for printing
    const scriptPath = path.join(__dirname, '..', 'static', 'print.js');
    const stylesPath = path.join(__dirname, '..', 'static', 'print-styles.css');
    const imgPath = path.join(__dirname, '..', 'assets', 'nylas-print-logo.png');
    const participantsHtml = participants.map((part) => {
      return (`<li class="participant"><span>${part.name} &lt;${part.email}&gt;</span></li>`);
    }).join('');

    const content = (`
      <html>
        <head>
          <meta charset="utf-8">
          ${styleTags}
          <link rel="stylesheet" type="text/css" href="${stylesPath}">
        </head>
        <body>
          <div id="print-header">
            <div onClick="continueAndPrint()" id="print-button">
              Print
            </div>
            <div class="logo-wrapper">
              <img src="${imgPath}" alt="nylas-logo"/>
              <span class="account">${account.name} &lt;${account.email}&gt;</span>
            </div>
            <h1>${subject}</h1>
          <div class="participants">
            <ul>
              ${participantsHtml}
            </ul>
          </div>
          </div>
          ${htmlContent}
          <script type="text/javascript">
            window.printMessages = ${printMessages}
          </script>
          <script type="text/javascript" src="${scriptPath}"></script>
        </body>
      </html>
    `);

    this.tmpFile = path.join(app.getPath('temp'), 'print.html');
    this.browserWin = new BrowserWindow({
      width: 800,
      height: 600,
      title: `Print - ${subject}`,
      webPreferences: {
        nodeIntegration: false,
      },
    });
    fs.writeFileSync(this.tmpFile, content);
  }

  /**
   * Load our temp html file. Once the file is loaded it will run print.js, and
   * that script will pop out the print dialog.
   */
  load() {
    this.browserWin.loadURL(`file://${this.tmpFile}`);
  }
}
