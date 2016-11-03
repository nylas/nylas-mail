import {
  Account,
  TaskQueue,
  AccountStore,
  DatabaseStore,
  ComponentRegistry,
  MailboxPerspective,
  FocusedPerspectiveStore,
} from 'nylas-exports';
import {clipboard} from 'electron';
import pathwatcher from 'pathwatcher';

import Config from '../../src/config';
import configUtils from '../../src/config-utils'
import TimeOverride from './time-override';
import nylasTestConstants from './nylas-test-constants'
import * as jasmineExtensions from './jasmine-extensions'


class MasterBeforeEach {
  setup(loadSettings, beforeEach) {
    this.loadSettings = loadSettings;
    const self = this;

    beforeEach(function jasmineBeforeEach() {
      const currentSpec = this;
      currentSpec.addMatchers({
        toHaveLength: jasmineExtensions.toHaveLength,
      })

      self._resetNylasEnv()
      self._resetDatabase()
      self._resetPackageManager()
      self._resetTaskQueue()
      self._resetTimeOverride()
      self._resetAccountStore()
      self._resetConfig()
      self._resetClipboard()
      ComponentRegistry._clear();

      advanceClock(1000);
      TimeOverride.resetSpyData();
    });
  }

  _resetNylasEnv() {
    NylasEnv.testOrganizationUnit = null;

    NylasEnv.workspaceViewParentSelector = '#jasmine-content';

    // Don't actually write to disk
    spyOn(NylasEnv, 'saveSync');

    // prevent specs from modifying N1's menus
    spyOn(NylasEnv.menu, 'sendToBrowserProcess');

    FocusedPerspectiveStore._current = MailboxPerspective.forNothing();

    spyOn(pathwatcher.File.prototype, "detectResurrectionAfterDelay").andCallFake(function detectResurrection() {
      return this.detectResurrection();
    });
  }

  _resetPackageManager = () => {
    NylasEnv.packages.packageStates = {};
  }

  _resetDatabase() {
    global.localStorage.clear();
    DatabaseStore._transactionQueue = undefined;

    // If we don't spy on DatabaseStore._query, then
    // `DatabaseStore.inTransaction` will never complete and cause all
    // tests that depend on transactions to hang.
    //
    // @_query("BEGIN IMMEDIATE TRANSACTION") never resolves because
    // DatabaseStore._query never runs because the @_open flag is always
    // false because we never setup the DB when `NylasEnv.inSpecMode` is
    // true.
    spyOn(DatabaseStore, '_query')
    .andCallFake(() => Promise.resolve([]));
  }

  _resetTaskQueue() {
    TaskQueue._queue = [];
    TaskQueue._completed = [];
    TaskQueue._onlineStatus = true;
  }

  _resetTimeOverride() {
    TimeOverride.resetTime();
    TimeOverride.enableSpies();
  }

  _resetAccountStore() {
    // Log in a fake user, and ensure that accountForId, etc. work
    AccountStore._accounts = [
      new Account({
        provider: "gmail",
        name: nylasTestConstants.TEST_ACCOUNT_NAME,
        emailAddress: nylasTestConstants.TEST_ACCOUNT_EMAIL,
        organizationUnit: NylasEnv.testOrganizationUnit || 'label',
        clientId: nylasTestConstants.TEST_ACCOUNT_CLIENT_ID,
        serverId: nylasTestConstants.TEST_ACCOUNT_ID,
        aliases: [
          `${nylasTestConstants.TEST_ACCOUNT_NAME} Alternate <${nylasTestConstants.TEST_ACCOUNT_ALIAS_EMAIL}>`,
        ],
      }),

      new Account({
        provider: "gmail",
        name: 'Second',
        emailAddress: 'second@gmail.com',
        organizationUnit: NylasEnv.testOrganizationUnit || 'label',
        clientId: 'second-test-account-id',
        serverId: 'second-test-account-id',
        aliases: [
          'Second Support <second@gmail.com>',
          'Second Alternate <second+alternate@gmail.com>',
          'Second <second+third@gmail.com>',
        ],
      }),
    ];
  }

  _resetConfig() {
    // reset config before each spec; don't load or save from/to `config.json`
    let fakePersistedConfig = {env: 'production'};
    spyOn(Config.prototype, 'getRawValues').andCallFake(() => {
      return fakePersistedConfig;
    }
    );
    spyOn(Config.prototype, 'setRawValue')
    .andCallFake(function setRawValue(keyPath, value) {
      if (keyPath) {
        configUtils.setValueForKeyPath(fakePersistedConfig, keyPath, value);
      } else {
        fakePersistedConfig = value;
      }
      return this.load();
    });
    NylasEnv.config = new Config();
    NylasEnv.loadConfig();
  }

  _resetClipboard() {
    let clipboardContent = 'initial clipboard content';
    spyOn(clipboard, 'writeText').andCallFake(text => {
      clipboardContent = text;
    });
    spyOn(clipboard, 'readText').andCallFake(() => clipboardContent);
  }
}
export default new MasterBeforeEach()
