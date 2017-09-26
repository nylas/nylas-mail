/*
 * "Squirrel will spawn your app with command line flags on first run, updates,]
 * and uninstalls."
 *
 * Read: https://github.com/electron-archive/grunt-electron-installer#handling-squirrel-events
 * Read: https://github.com/electron/electron/blob/master/docs/api/auto-updater.md#windows
 *
 * When Mailspring gets installed on a Windows machine it gets put in:
 * C:\Users\<USERNAME>\AppData\Local\NylasMail\app-x.x.x
 *
 * The `process.execPath` is:
 * C:\Users\<USERNAME>\AppData\Local\NylasMail\app-x.x.x\nylas.exe
 *
 * We manually copy everything in build/resources/win into a 'resources' folder
 * located inside the main app directory. See runCopyPlatformSpecificResources
 * in package-task.js
 *
 * This means `__dirname` should be:
 * C:\Users\<USERNAME>\AppData\Local\NylasMail\app-x.x.x\resources
 *
 * We also expect Squirrel Windows to have a file called `nylas.exe` at:
 * C:\Users\<USERNAME>\AppData\Local\NylasMail\nylas.exe
 */
const ChildProcess = require('child_process');
const fs = require('fs-plus');
const path = require('path');
const os = require('os');

// C:\Users\<USERNAME>\AppData\Local\NylasMail\app-x.x.x
const appFolder = path.resolve(process.execPath, '..');

// C:\Users\<USERNAME>\AppData\Local\NylasMail\
const rootN1Folder = path.resolve(appFolder, '..');

// C:\Users\<USERNAME>\AppData\Local\NylasMail\Update.exe
const updateDotExe = path.join(rootN1Folder, 'Update.exe');

// "nylas.exe"
const exeName = path.basename(process.execPath);

// Spawn a command and invoke the callback when it completes with an error
// and the output from standard out.
function spawn(command, args, callback, options = {}) {
  let stdout = '';
  let spawnedProcess = null;

  try {
    spawnedProcess = ChildProcess.spawn(command, args, options);
  } catch (error) {
    // Spawn can throw an error
    setTimeout(() => callback && callback(error, stdout), 0);
    return;
  }

  spawnedProcess.stdout.on('data', data => {
    stdout += data;
  });

  let error = null;
  spawnedProcess.on('error', processError => {
    error = error || processError;
  });

  spawnedProcess.on('close', (code, signal) => {
    if (code !== 0) {
      error = error || new Error(`Command failed: ${signal || code}`);
    }
    if (error) {
      error.code = error.code || code;
      error.stdout = error.stdout || stdout;
    }
    if (callback) {
      callback(error, stdout);
    }
  });
}

// Spawn the Update.exe with the given arguments and invoke the callback when
// the command completes.
function spawnUpdate(args, callback, options = {}) {
  spawn(updateDotExe, args, callback, options);
}

// Create a desktop and start menu shortcut by using the command line API
// provided by Squirrel's Update.exe
function createShortcuts(callback) {
  spawnUpdate(['--createShortcut', exeName], callback);
}

function createRegistryEntries({ allowEscalation, registerDefaultIfPossible }, callback) {
  const escapeBackticks = str => str.replace(/\\/g, '\\\\');

  const isWindows7 = os.release().startsWith('6.1');
  const requiresLocalMachine = isWindows7;

  // On Windows 7, we must write to LOCAL_MACHINE and need escalated privileges.
  // Don't do it at install time - wait for the user to ask N1 to be the default.
  if (requiresLocalMachine && !allowEscalation) {
    callback();
    return;
  }

  let regPath = 'reg.exe';
  if (process.env.SystemRoot) {
    regPath = path.join(process.env.SystemRoot, 'System32', 'reg.exe');
  }

  let spawnPath = regPath;
  let spawnArgs = [];
  if (requiresLocalMachine) {
    spawnPath = path.join(appFolder, 'resources', 'elevate.cmd');
    spawnArgs = [regPath];
  }

  fs.readFile(
    path.join(appFolder, 'resources', 'mailspring-mailto-registration.reg'),
    (err, data) => {
      if (err || !data) {
        callback(err);
        return;
      }
      const importTemplate = data.toString();
      let importContents = importTemplate.replace(
        /{{PATH_TO_ROOT_FOLDER}}/g,
        escapeBackticks(rootN1Folder)
      );
      importContents = importContents.replace(
        /{{PATH_TO_APP_FOLDER}}/g,
        escapeBackticks(appFolder)
      );
      if (requiresLocalMachine) {
        importContents = importContents.replace(/{{HKEY_ROOT}}/g, 'HKEY_LOCAL_MACHINE');
      } else {
        importContents = importContents.replace(/{{HKEY_ROOT}}/g, 'HKEY_CURRENT_USER');
      }

      const importTempPath = path.join(os.tmpdir(), `mailspring-reg-${Date.now()}.reg`);

      fs.writeFile(importTempPath, importContents, writeErr => {
        if (writeErr) {
          callback(writeErr);
          return;
        }

        spawn(
          spawnPath,
          spawnArgs.concat(['import', escapeBackticks(importTempPath)]),
          spawnErr => {
            if (isWindows7 && registerDefaultIfPossible) {
              const defaultReg = path.join(appFolder, 'resources', 'mailspring-mailto-default.reg');
              spawn(
                spawnPath,
                spawnArgs.concat(['import', escapeBackticks(defaultReg)]),
                spawnDefaultErr => {
                  callback(spawnDefaultErr, true);
                }
              );
            } else {
              callback(spawnErr, false);
            }
          }
        );
      });
    }
  );
}

// Remove the desktop and start menu shortcuts by using the command line API
// provided by Squirrel's Update.exe
function removeShortcuts(callback) {
  spawnUpdate(['--removeShortcut', exeName], callback);
}

exports.spawn = spawnUpdate;
exports.createShortcuts = createShortcuts;
exports.removeShortcuts = removeShortcuts;
exports.createRegistryEntries = createRegistryEntries;

// Is the Update.exe installed with N1?
exports.existsSync = () => fs.existsSync(updateDotExe);

// Restart N1 using the version pointed to by the N1.cmd shim
exports.restartMailspring = app => {
  app.once('will-quit', () => {
    spawnUpdate(['--processStart', exeName], () => {}, { detached: true });
  });
  app.quit();
};
