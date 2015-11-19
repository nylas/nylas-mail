import path from 'path'
import Promise from 'bluebird'
import {Application} from 'spectron';

class N1Launcher extends Application {
  constructor(launchArgs = []) {
    super({
      path: N1Launcher.electronPath(),
      args: [jasmine.NYLAS_ROOT_PATH].concat(N1Launcher.defaultNylasArgs()).concat(launchArgs)
    })
  }

  mainWindowReady() {
    // Wrap in a Bluebird promise so we have `.finally on the return`
    return Promise.resolve(this.start().then(()=>{
      return N1Launcher.waitUntilMainWindowLoaded(this.client).then((mainWindowId)=>{
        return this.client.window(mainWindowId)
      })
    }));
  }

  static defaultNylasArgs() {
    return ["--enable-logging", `--resource-path=${jasmine.NYLAS_ROOT_PATH}`]
  }

  static electronPath() {
    nylasRoot = jasmine.NYLAS_ROOT_PATH
    if (process.platform === "darwin") {
      return path.join(nylasRoot, "electron", "Electron.app", "Contents", "MacOS", "Electron")
    } else if (process.platform === "win32") {
      return path.join(nylasRoot, "electron", "electron.exe")
    }
    else if (process.platform === "linux") {
      return path.join(nylasRoot, "electron", "electron")
    }
    else {
      throw new Error(`Platform ${process.platform} is not supported`)
    }
  }

  // We unfortunatley can't just Spectron's `waitUntilWindowLoaded` because
  // the first window that loads isn't necessarily the main render window (it
  // could be the work window or others), and once the window is "loaded"
  // it'll take a while for packages to load, etc. As such we periodically
  // poll the list of windows to find one that looks like the main loaded
  // window.
  //
  // Returns a promise that resolves with the main window's ID once it's
  // loaded.
  static waitUntilMainWindowLoaded(client, lastCheck=0) {
    var CHECK_EVERY = 1000
    return new Promise((resolve, reject) => {
      client.windowHandles().then(({value}) => {
        return Promise.mapSeries(value, (windowId)=>{
          return N1Launcher.switchAndCheckForMain(client, windowId)
        })
      }).then((mainChecks)=>{
        for (mainWindowId of mainChecks) {
          if (mainWindowId) {return resolve(mainWindowId)}
        }

        var now = Date.now();
        var delay = Math.max(CHECK_EVERY - (now - lastCheck), 0)
        setTimeout(()=>{
          N1Launcher.waitUntilMainWindowLoaded(client, now).then(resolve)
        }, delay)
      }).catch((err) => {
        console.error(err);
      });
    });
  }

  // Returns false or the window ID of the main window
  static switchAndCheckForMain(client, windowId) {
    return client.window(windowId).then(()=>{
      return client.isExisting(".main-window-loaded").then((exists)=>{
        if (exists) {return windowId} else {return false}
      })
    })
  }
}

module.exports = {N1Launcher}
