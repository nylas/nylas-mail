import { exec } from 'child_process';
import fs from 'fs';
import { remote, shell } from 'electron';

const bundleIdentifier = 'com.mailspring.mailspring';

class Windows {
  available() {
    return true;
  }

  isRegisteredForURLScheme(scheme, callback) {
    if (!callback) {
      throw new Error('isRegisteredForURLScheme is async, provide a callback');
    }
    let output = '';
    exec(
      `reg.exe query HKCU\\SOFTWARE\\Microsoft\\Windows\\Roaming\\OpenWith\\UrlAssociations\\${scheme}\\UserChoice`,
      (err1, stdout1) => {
        output += stdout1.toString();
        exec(
          `reg.exe query HKCU\\SOFTWARE\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\${scheme}\\UserChoice`,
          (err2, stdout2) => {
            output += stdout2.toString();
            if (err1 || err2) {
              callback(err1 || err2);
              return;
            }
            callback(output.includes('Nylas'));
          }
        );
      }
    );
  }

  resetURLScheme() {
    remote.dialog.showMessageBox(
      null,
      {
        type: 'info',
        buttons: ['Learn More'],
        message: 'Visit Windows Settings to change your default mail client',
        detail: "You'll find Mailspring, along with other options, listed in Default Apps > Mail.",
      },
      () => {
        shell.openExternal(
          'http://support.getmailspring.com/hc/en-us/articles/115001881412-Choose-Mailspring-as-the-default-mail-client-on-Windows'
        );
      }
    );
  }

  registerForURLScheme(scheme, callback = () => {}) {
    // Ensure that our registry entires are present
    const WindowsUpdater = remote.require('./windows-updater');
    WindowsUpdater.createRegistryEntries(
      {
        allowEscalation: true,
        registerDefaultIfPossible: true,
      },
      (err, didMakeDefault) => {
        if (err) {
          remote.dialog.showMessageBox(null, {
            type: 'error',
            buttons: ['OK'],
            message: 'Sorry, an error occurred.',
            detail: err.message,
          });
        }
        if (!didMakeDefault) {
          remote.dialog.showMessageBox(
            null,
            {
              type: 'info',
              buttons: ['Learn More'],
              defaultId: 1,
              message: 'Visit Windows Settings to finish making Mailspring your mail client',
              detail: "Click 'Learn More' to view instructions in our knowledge base.",
            },
            () => {
              shell.openExternal(
                'http://support.getmailspring.com/hc/en-us/articles/115001881412-Choose-Mailspring-as-the-default-mail-client-on-Windows'
              );
            }
          );
        }
        callback(null, null);
      }
    );
  }
}

class Linux {
  available() {
    return !process.env.SNAP;
  }

  isRegisteredForURLScheme(scheme, callback) {
    if (!callback) {
      throw new Error('isRegisteredForURLScheme is async, provide a callback');
    }
    exec(
      `xdg-mime query default x-scheme-handler/${scheme}`,
      (err, stdout) => (err ? callback(err) : callback(stdout.trim() === 'mailspring.desktop'))
    );
  }

  resetURLScheme(scheme, callback = () => {}) {
    exec(
      `xdg-mime default thunderbird.desktop x-scheme-handler/${scheme}`,
      err => (err ? callback(err) : callback(null, null))
    );
  }
  registerForURLScheme(scheme, callback = () => {}) {
    exec(
      `xdg-mime default mailspring.desktop x-scheme-handler/${scheme}`,
      err => (err ? callback(err) : callback(null, null))
    );
  }
}

class Mac {
  constructor() {
    this.secure = false;
  }

  available() {
    return true;
  }

  getLaunchServicesPlistPath(callback) {
    const secure = `${process.env
      .HOME}/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist`;
    const insecure = `${process.env.HOME}/Library/Preferences/com.apple.LaunchServices.plist`;

    fs.exists(secure, exists => (exists ? callback(secure) : callback(insecure)));
  }

  readDefaults(callback = () => {}) {
    this.getLaunchServicesPlistPath(plistPath => {
      const tmpPath = `${plistPath}.${Math.random()}`;
      exec(`plutil -convert json "${plistPath}" -o "${tmpPath}"`, err => {
        if (err) {
          callback(err);
          return;
        }
        fs.readFile(tmpPath, (readErr, data) => {
          if (readErr) {
            callback(readErr);
            return;
          }
          try {
            const json = JSON.parse(data);
            callback(json.LSHandlers, json);
            fs.unlink(tmpPath, () => {});
          } catch (e) {
            callback(e);
          }
        });
      });
    });
  }

  writeDefaults(defaults, callback = () => {}) {
    this.getLaunchServicesPlistPath(plistPath => {
      const tmpPath = `${plistPath}.${Math.random()}`;
      exec(`plutil -convert json "${plistPath}" -o "${tmpPath}"`, err => {
        if (err) {
          callback(err);
          return;
        }
        try {
          let data = fs.readFileSync(tmpPath);
          data = JSON.parse(data);
          data.LSHandlers = defaults;
          data = JSON.stringify(data);
          fs.writeFileSync(tmpPath, data);
        } catch (e) {
          callback(e);
          return;
        }
        exec(`plutil -convert binary1 "${tmpPath}" -o "${plistPath}"`, () => {
          fs.unlink(tmpPath, () => {});
          exec(
            '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user',
            registerErr => {
              callback(registerErr);
            }
          );
        });
      });
    });
  }

  isRegisteredForURLScheme(scheme, callback) {
    if (!callback) {
      throw new Error('isRegisteredForURLScheme is async, provide a callback');
    }
    this.readDefaults(defaults => {
      for (const def of defaults) {
        if (def.LSHandlerURLScheme === scheme) {
          callback(def.LSHandlerRoleAll === bundleIdentifier);
          return;
        }
      }
      callback(false);
    });
  }

  resetURLScheme(scheme, callback) {
    this.readDefaults(defaults => {
      // Remove anything already registered for the scheme
      for (let ii = defaults.length - 1; ii >= 0; ii--) {
        if (defaults[ii].LSHandlerURLScheme === scheme) {
          defaults.splice(ii, 1);
        }
      }
      this.writeDefaults(defaults, callback);
    });
  }

  registerForURLScheme(scheme, callback) {
    this.readDefaults(defaults => {
      // Remove anything already registered for the scheme
      for (let ii = defaults.length - 1; ii >= 0; ii--) {
        if (defaults[ii].LSHandlerURLScheme === scheme) {
          defaults.splice(ii, 1);
        }
      }

      // Add our scheme default
      defaults.push({
        LSHandlerURLScheme: scheme,
        LSHandlerRoleAll: bundleIdentifier,
      });

      this.writeDefaults(defaults, callback);
    });
  }
}

if (process.platform === 'darwin') {
  module.exports = Mac;
} else if (process.platform === 'linux') {
  module.exports = Linux;
} else if (process.platform === 'win32') {
  module.exports = Windows;
} else {
  module.exports = {};
}
module.exports.Mac = Mac;
module.exports.Linux = Linux;
module.exports.Windows = Windows;
