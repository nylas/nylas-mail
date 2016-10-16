import _ from 'underscore';
import fs from 'fs-plus';
import path from 'path';

import '../../src/window';
NylasEnv.restoreWindowDimensions();

import 'jasmine-json';

import Grim from 'grim';
import TimeOverride from './time-override';

import Config from '../../src/config';
import pathwatcher from 'pathwatcher';
import { clipboard } from 'electron';

import { Account, TaskQueue, AccountStore, DatabaseStore, MailboxPerspective, FocusedPerspectiveStore, ComponentRegistry } from "nylas-exports";

NylasEnv.themes.loadBaseStylesheets();
NylasEnv.themes.requireStylesheet('../static/jasmine');
NylasEnv.themes.initialLoadComplete = true;

NylasEnv.keymaps.loadKeymaps();
const styleElementsToRestore = NylasEnv.styles.getSnapshot();

window.addEventListener('core:close', () => window.close());
window.addEventListener('beforeunload', function() {
  NylasEnv.storeWindowDimensions();
  return NylasEnv.saveSync();
}
);

document.querySelector('html').style.overflow = 'initial';
document.querySelector('body').style.overflow = 'initial';

// Allow document.title to be assigned in specs without screwing up spec window title
let documentTitle = null;
Object.defineProperty(document, 'title', {
  get() { return documentTitle; },
  set(title) { return documentTitle = title; }
}
);

jasmine.getEnv().addEqualityTester(_.isEqual); // Use underscore's definition of equality for toEqual assertions

//
//

if (process.env.JANKY_SHA1 && process.platform === 'win32') {
  jasmine.getEnv().defaultTimeoutInterval = 60000;
} else {
  jasmine.getEnv().defaultTimeoutInterval = 250;
}

let specPackageName = null;
let specPackagePath = null;
let isCoreSpec = false;

let {specDirectory, resourcePath} = NylasEnv.getLoadSettings();

if (specDirectory) {
  specPackagePath = path.resolve(specDirectory, '..');
  try {
    specPackageName = __guard__(JSON.parse(fs.readFileSync(path.join(specPackagePath, 'package.json'))), x => x.name);
  } catch (error) {}
}

isCoreSpec = specDirectory === fs.realpathSync(__dirname);

// Override ReactTestUtils.renderIntoDocument so that
// we can remove all the created elements after the test completes.
import React from "react";
import ReactDOM from "react-dom";

import ReactTestUtils from 'react-addons-test-utils';
ReactTestUtils.scryRenderedComponentsWithTypeAndProps = function(root, type, props) {
  if (!root) { throw new Error("Must supply a root to scryRenderedComponentsWithTypeAndProps"); }
  return _.compact(_.map(ReactTestUtils.scryRenderedComponentsWithType(root, type), function(el) {
    if (_.isEqual(_.pick(el.props, Object.keys(props)), props)) {
      return el;
    } else {
      return false;
    }
  }
  )
  );
};

let ReactElementContainers = [];
ReactTestUtils.renderIntoDocument = function(element) {
  let container = document.createElement('div');
  ReactElementContainers.push(container);
  return ReactDOM.render(element, container);
};

ReactTestUtils.unmountAll = function() {
  for (let i = 0; i < ReactElementContainers.length; i++) {
    let container = ReactElementContainers[i];
    ReactDOM.unmountComponentAtNode(container);
  }
  return ReactElementContainers = [];
};

// So it passes the Utils.isTempId test
window.TEST_ACCOUNT_CLIENT_ID = "local-test-account-client-id";
window.TEST_ACCOUNT_ID = "test-account-server-id";
window.TEST_ACCOUNT_EMAIL = "tester@nylas.com";
window.TEST_ACCOUNT_NAME = "Nylas Test";
window.TEST_PLUGIN_ID = "test-plugin-id-123";
window.TEST_ACCOUNT_ALIAS_EMAIL = "tester+alternative@nylas.com";

window.TEST_TIME_ZONE = "America/Los_Angeles";
import moment from 'moment-timezone';
// moment-round upon require patches `moment` with new functions.
import 'moment-round';

// This date was chosen because it's close to a DST boundary
window.testNowMoment = () => moment.tz("2016-03-15 12:00", TEST_TIME_ZONE);

// We need to mock the config even before `beforeEach` runs because it gets
// accessed on module definitions
let fakePersistedConfig = {env: 'production'};
NylasEnv.config = new Config();
NylasEnv.config.settings = fakePersistedConfig;

beforeEach(function() {
  NylasEnv.testOrganizationUnit = null;
  if (isCoreSpec) { Grim.clearDeprecations(); }
  ComponentRegistry._clear();
  global.localStorage.clear();

  DatabaseStore._transactionQueue = undefined;

  //# If we don't spy on DatabaseStore._query, then
  //`DatabaseStore.inTransaction` will never complete and cause all tests
  //that depend on transactions to hang.
  //
  // @_query("BEGIN IMMEDIATE TRANSACTION") never resolves because
  // DatabaseStore._query never runs because the @_open flag is always
  // false because we never setup the DB when `NylasEnv.inSpecMode` is
  // true.
  spyOn(DatabaseStore, '_query').andCallFake(() => Promise.resolve([]));

  TaskQueue._queue = [];
  TaskQueue._completed = [];
  TaskQueue._onlineStatus = true;

  documentTitle = null;
  NylasEnv.styles.restoreSnapshot(styleElementsToRestore);
  NylasEnv.workspaceViewParentSelector = '#jasmine-content';

  NylasEnv.packages.packageStates = {};

  let serializedWindowState = null;

  spyOn(NylasEnv, 'saveSync');

  TimeOverride.resetTime();
  TimeOverride.enableSpies();

  let spy = spyOn(NylasEnv.packages, 'resolvePackagePath').andCallFake(function(packageName) {
    if (specPackageName && packageName === specPackageName) {
      return resolvePackagePath(specPackagePath);
    } else {
      return resolvePackagePath(packageName);
    }
  });
  var resolvePackagePath = _.bind(spy.originalValue, NylasEnv.packages);

  // prevent specs from modifying N1's menus
  spyOn(NylasEnv.menu, 'sendToBrowserProcess');

  // Log in a fake user, and ensure that accountForId, etc. work
  AccountStore._accounts = [
    new Account({
      provider: "gmail",
      name: TEST_ACCOUNT_NAME,
      emailAddress: TEST_ACCOUNT_EMAIL,
      organizationUnit: NylasEnv.testOrganizationUnit || 'label',
      clientId: TEST_ACCOUNT_CLIENT_ID,
      serverId: TEST_ACCOUNT_ID,
      aliases: [
        `${TEST_ACCOUNT_NAME} Alternate <${TEST_ACCOUNT_ALIAS_EMAIL}>`
      ]
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
        'Second <second+third@gmail.com>'
      ]
    })
  ];

  FocusedPerspectiveStore._current = MailboxPerspective.forNothing();

  // reset config before each spec; don't load or save from/to `config.json`
  fakePersistedConfig = {env: 'production'};
  spyOn(Config.prototype, 'getRawValues').andCallFake(() => {
    return fakePersistedConfig;
  }
  );
  spyOn(Config.prototype, 'setRawValue').andCallFake(function(keyPath, value) {
    if (keyPath) {
      _.setValueForKeyPath(fakePersistedConfig, keyPath, value);
    } else {
      fakePersistedConfig = value;
    }
    return this.load();
  });
  NylasEnv.config = new Config();
  NylasEnv.loadConfig();

  spyOn(pathwatcher.File.prototype, "detectResurrectionAfterDelay").andCallFake(function() {
    return this.detectResurrection();
  });

  let clipboardContent = 'initial clipboard content';
  spyOn(clipboard, 'writeText').andCallFake(text => clipboardContent = text);
  spyOn(clipboard, 'readText').andCallFake(() => clipboardContent);

  advanceClock(1000);
  addCustomMatchers(this);

  return TimeOverride.resetSpyData();
});


afterEach(function() {
  NylasEnv.packages.deactivatePackages();
  NylasEnv.menu.template = [];

  NylasEnv.themes.removeStylesheet('global-editor-styles');

  if (NylasEnv.state) {
    delete NylasEnv.state.packageStates;
  }

  if (!window.debugContent) {
    document.getElementById('jasmine-content').innerHTML = '';
  }
  ReactTestUtils.unmountAll();

  jasmine.unspy(NylasEnv, 'saveSync');
  ensureNoPathSubscriptions();
  return waits(0);
}); // yield to ui thread to make screen update more frequently

var ensureNoPathSubscriptions = function() {
  let watchedPaths = pathwatcher.getWatchedPaths();
  pathwatcher.closeAllWatchers();
  if (watchedPaths.length > 0) {
    throw new Error(`Leaking subscriptions for paths: ${watchedPaths.join(", ")}`);
  }
};

let { emitObject } = jasmine.StringPrettyPrinter.prototype;
jasmine.StringPrettyPrinter.prototype.emitObject = function(obj) {
  if (obj.inspect) {
    return this.append(obj.inspect());
  } else {
    return emitObject.call(this, obj);
  }
};

jasmine.unspy = function(object, methodName) {
  if (!object[methodName].hasOwnProperty('originalValue')) { throw new Error("Not a spy"); }
  return object[methodName] = object[methodName].originalValue;
};

jasmine.attachToDOM = function(element) {
  let jasmineContent = document.querySelector('#jasmine-content');
  if (!jasmineContent.contains(element)) { return jasmineContent.appendChild(element); }
};

let deprecationsSnapshot = null;
jasmine.snapshotDeprecations = () => deprecationsSnapshot = _.clone(Grim.deprecations);

jasmine.restoreDeprecationsSnapshot = () => Grim.deprecations = deprecationsSnapshot;

var addCustomMatchers = spec =>
  spec.addMatchers({
    toHaveLength(expected) {
      if (this.actual == null) {
        this.message = () => `Expected object ${this.actual} has no length method`;
        return false;
      } else {
        let notText = this.isNot ? " not" : "";
        this.message = () => `Expected object with length ${this.actual.length} to${notText} have length ${expected}`;
        return this.actual.length === expected;
      }
    }
  })
;

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}
