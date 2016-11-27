const util = require('./modules/util');
const fs = require('fs-extra');
const stripJsonComments = require('strip-json-comments');

module.exports = {
  // configure() needs to be called at the beginning of main.jsx
  // Loads user settings or reverts to defaults
  //
  configure: () => {
    const defaultSettings = `${__dirname}/../unsubscribe-settings.defaults.json`;
    const userSettings = `${__dirname}/../unsubscribe-settings.json`;
    let settingsFile;
    try {
      settingsFile = fs.readFileSync(userSettings, 'utf8');
    } catch (e) {
      console.log(`n1-unsubscribe: Copying default settings to ${userSettings}.`);
      fs.copySync(defaultSettings, userSettings);
      settingsFile = fs.readFileSync(userSettings, 'utf8');
    }
    const settingsJSON = stripJsonComments(settingsFile);
    const settings = JSON.parse(settingsJSON);

    // Configure global variables
    process.env.N1_UNSUBSCRIBE_USE_BROWSER = settings.use_browser === true ||
      settings.use_browser === 'true';
    process.env.N1_UNSUBSCRIBE_THREAD_HANDLING = settings.handle_threads;
    process.env.N1_UNSUBSCRIBE_CONFIRM_EMAIL = settings.confirm_for_email === true ||
      settings.confirm_for_email === 'true';
    process.env.N1_UNSUBSCRIBE_CONFIRM_BROWSER = settings.confirm_for_browser === true ||
      settings.confirm_for_browser === 'true';
    process.env.N1_UNSUBSCRIBE_DEBUG = settings.debug === true ||
      settings.debug === 'true';

    // Print settings file to console
    const browserText = (process.env.n1UnsubscribeUseBrowser === 'true' ? '' : '(Popup)');
    const useBrowser = process.env.N1_UNSUBSCRIBE_USE_BROWSER;
    util.logIfDebug(
      `n1-unsubscribe settings:
      - Use preferred browser for unsubscribing: ${useBrowser} ${browserText}
      - Archive or trash after unsubscribing: ${process.env.N1_UNSUBSCRIBE_THREAD_HANDLING}
      - Confirm before email unsubscribing: ${process.env.N1_UNSUBSCRIBE_CONFIRM_EMAIL}
      - Confirm before browser unsubscribing: ${process.env.N1_UNSUBSCRIBE_CONFIRM_BROWSER}
      - Print maximum debugging logs: ${process.env.N1_UNSUBSCRIBE_DEBUG}`
    );
  },
}
