import path from 'path';
import {Application} from 'spectron';
import {clearConfig,
        setupDefaultConfig,
        FAKE_DATA_PATH,
        CONFIG_DIR_PATH} from './config-helper';

export default class N1Launcher extends Application {
  constructor(launchArgs = [], configOpts) {
    if (configOpts === N1Launcher.CLEAR_CONFIG) {
      clearConfig();
    } else {
      setupDefaultConfig();
    }

    super({
      path: N1Launcher.electronPath(),
      args: [jasmine.NYLAS_ROOT_PATH].concat(N1Launcher.defaultNylasArgs()).concat(launchArgs),
    });
  }

  onboardingWindowReady() {
    return this.windowReady(N1Launcher.secondaryWindowLoadedMatcher);
  }

  mainWindowReady() {
    return this.windowReady(N1Launcher.mainWindowLoadedMatcher).then(() => {
      return this.client
      .timeoutsAsyncScript(5000)
      .executeAsync((fakeDataPath, done) => {
        $n.AccountStore._importFakeData(fakeDataPath).then(done);
      }, FAKE_DATA_PATH);
    });
  }

  popoutComposerWindowReady() {
    return this.windowReady(N1Launcher.mainWindowLoadedMatcher).then(() => {
      return this.client
      .timeoutsAsyncScript(5000)
      .executeAsync((fakeDataPath, done) => {
        return $n.AccountStore._importFakeData(fakeDataPath).then(()=> {
          $n.Actions.composeNewBlankDraft();
          done();
        });
      }, FAKE_DATA_PATH);
    }).then(()=>{
      return N1Launcher.waitUntilMatchingWindowLoaded(this.client, N1Launcher.composerWindowMatcher).then((windowId)=>{
        return new Promise((resolve) => {
          setTimeout(() => {
            resolve(this.client.window(windowId));
          }, 500);
        });
      });
    });
  }

  windowReady(matcher) {
    return this.start().then(()=>{
      return N1Launcher.waitUntilMatchingWindowLoaded(this.client, matcher).then((windowId)=>{
        return this.client.window(windowId);
      });
    });
  }

  static secondaryWindowLoadedMatcher(client) {
    // The last thing secondary windows do once they boot is call "show"
    return client.isWindowVisible();
  }

  static mainWindowLoadedMatcher(client) {
    return client.isExisting('.window-loaded').then((exists)=> {
      if (exists) return true;
      return false;
    });
  }

  static composerWindowMatcher(client) {
    return client.execute(()=>{
      return NylasEnv.getLoadSettings().windowType;
    }).then(({value})=>{
      if (value === 'composer') {
        return client.isExisting('.contenteditable');
      }
      return false;
    });
  }

  static defaultNylasArgs() {
    return ['--enable-logging',
            `--resource-path=${jasmine.NYLAS_ROOT_PATH}`,
            `--config-dir-path=${CONFIG_DIR_PATH}`];
  }

  static electronPath() {
    const nylasRoot = jasmine.NYLAS_ROOT_PATH;
    if (process.platform === 'darwin') {
      return path.join(nylasRoot, 'electron', 'Electron.app', 'Contents', 'MacOS', 'Electron');
    } else if (process.platform === 'win32') {
      return path.join(nylasRoot, 'electron', 'electron.exe');
    } else if (process.platform === 'linux') {
      return path.join(nylasRoot, 'electron', 'electron');
    }
    throw new Error(`Platform ${process.platform} is not supported`);
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
  static waitUntilMatchingWindowLoaded(client, matcher, lastCheck = 0) {
    const CHECK_EVERY = 500;
    return new Promise((resolve) => {
      return client.windowHandles().then(({value}) => {
        return Promise.mapSeries(value, (windowId)=>{
          return N1Launcher.switchAndCheckForMatch(client, windowId, matcher);
        });
      }).then((windowIdChecks)=>{
        for (const windowId of windowIdChecks) {
          if (windowId) return resolve(windowId);
        }

        const now = Date.now();
        const delay = Math.max(CHECK_EVERY - (now - lastCheck), 0);
        setTimeout(()=>{
          return N1Launcher.waitUntilMatchingWindowLoaded(client, matcher, now).then(resolve);
        }, delay);
        return null;
      }).catch((err) => {
        console.error(err);
        return null;
      });
    });
  }

  // Returns false or the window ID of the main window
  // The `matcher` resolves to a boolean.
  static switchAndCheckForMatch(client, windowId, matcher) {
    return client.window(windowId).then(()=>{
      return matcher(client).then((isMatch) => {
        if (isMatch) return windowId;
        return false;
      });
    });
  }
}
N1Launcher.CLEAR_CONFIG = 'CLEAR_CONFIG';
