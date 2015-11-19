import {N1Launcher} from './integration-helper'

// Some unit tests, such as the Contenteditable specs need to be run with
// Spectron availble in the environment.
fdescribe('Integrated Unit Tests', function() {
  beforeAll((done)=>{
    // Boot in dev mode with no arguments
    this.app = new N1Launcher(["--test=window"]);
    this.app.start().then(done).catch(done)
    this.originalTimeoutInterval = jasmine.DEFAULT_TIMEOUT_INTERVAL
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 5*60*1000 // 5 minutes
  });

  afterAll((done)=> {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = this.originalTimeoutInterval
    if (this.app && this.app.isRunning()) {
      this.app.stop().then(done);
    } else {
      done()
    }
  });

  it("Passes all integrated unit tests", (done)=> {
    var client = this.app.client
    client.waitForExist(".specs-complete", jasmine.UNIT_TEST_TIMEOUT)
    .then(()=>{ return client.getHTML(".specs-complete .message") })
    .then((results)=>{
      expect(results).toMatch(/0 failures/)
    }).then(()=>{ return client.getHTML(".plain-text-output") })
    .then((errorOutput)=>{
      expect(errorOutput).toBe('<pre class="plain-text-output"></pre>')
      done()
    }).catch(done)
  });

});
