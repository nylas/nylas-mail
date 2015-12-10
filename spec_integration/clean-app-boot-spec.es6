import N1Launcher from './helpers/n1-launcher'
import {currentConfig} from './helpers/config-helper'
import {assertBasicWindow} from './helpers/shared-assertions'

describe('Clean app boot', function() {
  beforeAll((done)=>{
    // Boot in dev mode with no arguments
    this.app = new N1Launcher(["--dev"], N1Launcher.CLEAR_CONFIG);
    this.app.onboardingWindowReady().finally(done);
  });

  afterAll((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().finally(done);
    } else {
      done()
    }
  });

  it("has the autoupdater pointing to the correct url when there's no config loaded", () => {
    this.app.client.execute(()=>{
      app = require('remote').getGlobal('application')
      return {
        platform: process.platform,
        arch: process.arch,
        feedUrl: app.autoUpdateManager.feedURL
      }
    }).then(({value})=>{
      base = "https://edgehill.nylas.com/update-check"
      config = currentConfig()
      // NOTE: Since there's no loaded config yet (we haven't logged in),
      // a random id will be sent with no emails
      url = `${base}?platform=${value.platform}&arch=${value.arch}&version=${config.version}`
      expect(value.feedUrl.indexOf(url)).toBe(0)
    })
  });

  assertBasicWindow.call(this)

  it("has width", (done)=> {
    this.app.client.getWindowWidth()
    .then((result)=>{ expect(result).toBeGreaterThan(0) })
    .finally(done)
  });

  it("has height", (done)=> {
    this.app.client.getWindowHeight()
    .then((result)=>{ expect(result).toBeGreaterThan(0) })
    .finally(done)
  });
});
