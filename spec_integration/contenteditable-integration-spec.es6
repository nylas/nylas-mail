import Promise from 'bluebird'
import {N1Launcher} from './integration-helper'
import ContenteditableTestHarness from './contenteditable-test-harness.es6'

fdescribe('Contenteditable Integration Spec', function() {
  beforeAll((done)=>{
    console.log("----------- BEFORE ALL");
    // Boot in dev mode with no arguments
    this.app = new N1Launcher(["--dev"]);
    this.app.popoutComposerWindowReady().finally(done);
  });

  beforeEach((done) => {
    console.log("----------- BEFORE EACH");
    this.ce = new ContenteditableTestHarness(this.app.client, expect)
    this.ce.init().finally(done);
  });

  afterAll((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().then(done);
    } else {
      done()
    }
  });

  fit("Creates ordered lists", (done)=> {
    console.log("RUNNING KEYS");
    this.app.client.keys(["1", ".", "Space"]).then(()=>{
      console.log("DONE FIRING KEYS");
      e1 = this.ce.expectHTML("<ol><li>WOOO</li></ol>")
      e2 = this.ce.expectSelection((dom) => {
        return {node: dom.querySelectorAll("li")[0]}
      })
      return Promise.all(e1,e2)
    }).catch((err)=>{ console.log("XXXX ERROR"); console.log(err); }).finally(done)
  });

  it("has main window visible", (done)=> {
    this.app.client.isWindowVisible()
    .then((result)=>{ expect(result).toBe(true) })
    .finally(done)
  });

  it("has main window focused", (done)=> {
    this.app.client.isWindowFocused()
    .then((result)=>{ expect(result).toBe(true) })
    .finally(done)
  });

  it("isn't minimized", (done)=> {
    this.app.client.isWindowMinimized()
    .then((result)=>{ expect(result).toBe(false) })
    .finally(done)
  });

  it("doesn't have the dev tools open", (done)=> {
    this.app.client.isWindowDevToolsOpened()
    .then((result)=>{ expect(result).toBe(false) })
    .finally(done)
  });

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
