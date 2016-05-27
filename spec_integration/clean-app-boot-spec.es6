import fs from 'fs';
import path from 'path';
import N1Launcher from './helpers/n1-launcher';
import {currentConfig, FAKE_DATA_PATH} from './helpers/config-helper';
import {assertBasicWindow, assertNoErrorsInLogs} from './helpers/shared-assertions';
import {clickRepeat, wait} from './helpers/client-actions';

describe('Clean app boot', ()=> {
  beforeAll((done)=>{
    // Boot in dev mode with no arguments
    this.app = new N1Launcher(['--dev'], N1Launcher.CLEAR_CONFIG);
    this.app.onboardingWindowReady().finally(done);
  });

  afterAll((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().finally(done);
    } else {
      done();
    }
  });

  it("has the autoupdater pointing to the correct url when there's no config loaded", () => {
    this.app.client.execute(()=>{
      const app = require('electron').remote.getGlobal('application');
      return {
        platform: process.platform,
        arch: process.arch,
        feedUrl: app.autoUpdateManager.feedURL,
      };
    }).then(({value})=>{
      const base = 'https://edgehill.nylas.com/update-check';
      const config = currentConfig();
      // NOTE: Since there's no loaded config yet (we haven't logged in),
      // a random id will be sent with no emails
      const url = `${base}?platform=${value.platform}&arch=${value.arch}&version=${config.version}`;
      expect(value.feedUrl.indexOf(url)).toBe(0);
    });
  });

  assertBasicWindow.call(this);

  it('has width', (done)=> {
    this.app.client.getWindowWidth()
    .then((result)=> expect(result).toBeGreaterThan(0) )
    .finally(done);
  });

  it('has height', (done)=> {
    this.app.client.getWindowHeight()
    .then((result)=> expect(result).toBeGreaterThan(0) )
    .finally(done);
  });

  it('can sign up using Gmail', ()=> {
    // TODO
  });

  it('can sign up using Exchange', (done)=> {
    const client = this.app.client;
    const fakeAccountJson = fs.readFileSync(
      path.join(FAKE_DATA_PATH, 'account_exchange.json'),
      'utf8'
    );

    client.execute((jsonStr)=> {
      // Monkeypatch NylasAPI and EdgehillAPI
      const json = JSON.parse(jsonStr);
      $n._nylasApiMakeRequest = $n.NylasAPI.makeRequest;
      $n._edgehillRequest = $n.EdgehillAPI.makeRequest;
      $n.NylasAPI.makeRequest = ()=> {
        return Promise.resolve(json);
      };
      $n.EdgehillAPI.makeRequest = ({success})=> {
        success(json);
      };
    }, fakeAccountJson)
    .then(()=> clickRepeat(client, '.btn-continue', {times: 3, interval: 500}))
    .then(()=> client.click('.provider.exchange'))
    .then(()=> wait(500))
    .then(()=> client.click('input[data-field="name"]'))
    .then(()=> client.keys('name'))
    .then(()=> client.click('input[data-field="email"]'))
    .then(()=> client.keys('email@nylas.com'))
    .then(()=> client.click('input[data-field="password"]'))
    .then(()=> client.keys('password'))
    .then(()=> client.click('.btn-add-account'))
    .then(()=> wait(500))
    .then(()=> {
      // Expect the onboarding window to have no errors at this point
      return assertNoErrorsInLogs(client);
    })
    .then(()=> client.click('button.btn-large'))
    .then(()=> wait(500))
    .then(()=> client.click('.btn-get-started'))
    .then(()=> wait(500))
    .then(()=> N1Launcher.waitUntilMatchingWindowLoaded(client, N1Launcher.mainWindowLoadedMatcher))
    .then(()=> {
      // Expect the main window logs to contain no errors
      // This will run on the main window because waitUntilMatchingWindowLoaded
      // focuses the window after its loaded
      return assertNoErrorsInLogs(client);
    })
    .finally(done);
  });
});
