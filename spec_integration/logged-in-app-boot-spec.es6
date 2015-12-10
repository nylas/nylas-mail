import N1Launcher from './helpers/n1-launcher'
import {currentConfig} from './helpers/config-helper'
import {assertBasicWindow} from './helpers/shared-assertions'

describe('Logged in app boot', () => {
  beforeAll((done)=>{
    // Boot in dev mode with no arguments
    this.app = new N1Launcher(["--dev"]);
    this.app.mainWindowReady().finally(done);
  });

  afterAll((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().finally(done);
    } else {
      done()
    }
  });

  it("has the autoupdater pointing to the correct url", () => {
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
      email = encodeURIComponent(config.email)
      url = `${base}?platform=${value.platform}&arch=${value.arch}&version=${config.version}&id=${config.id}&emails=${email}`
      expect(value.feedUrl).toEqual(url)
    })
  });

  assertBasicWindow.call(this)

  it("restored its width from file", (done)=> {
    this.app.client.getWindowWidth()
    .then((result)=>{ expect(result).toBe(1234) })
    .finally(done)
  });

  it("restored its height from file", (done)=> {
    this.app.client.getWindowHeight()
    .then((result)=>{ expect(result).toBe(789) })
    .finally(done)
  });
});
