import {N1Launcher} from './integration-helper'
import ContenteditableTestHarness from './contenteditable-test-harness.es6'

fdescribe('Contenteditable Integration Spec', function() {
  beforeAll((done)=>{
    this.app = new N1Launcher(["--dev"]);
    this.app.popoutComposerWindowReady().finally(done);
  });

  beforeEach((done) => {
    this.ce = new ContenteditableTestHarness(this.app.client)
    this.ce.init().finally(done);
  });

  afterAll((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().then(done);
    } else {
      done()
    }
  });



  describe('Manipulating Lists', () => {
    it("Creates ordered lists", (done)=> {
      this.ce.test({
        keys: ["1", ".", "Space"],
        expectedHTML: "<ol><li></li></ol>",
        expectedSelectionResolver: (dom) => {
          return {node: dom.querySelectorAll('li')[0]} }
      }).then(done).catch(done.fail)
    });

    it('Undoes ordered list creation with backspace', (done) => {
      this.ce.test({
        keys: ["1", ".", "Space", "Back space"],
        expectedHTML: "1.&nbsp;<br>",
        expectedSelectionResolver: (dom) => {
          return {node: dom.childNodes[0], offset: 3} }
      }).then(done).catch(done.fail)
    });

    it("Creates unordered lists with star", (done) => {
      this.ce.test({
        keys: ['*', 'Space'],
        expectedHTML: "<ul><li></li></ul>",
        expectedSelectionResolver: (dom) => {
          return {node: dom.querySelectorAll("li")[0] } }
      }).then(done).catch(done.fail)
    });

    it("Undoes unordered list creation with backspace", (done) => {
      this.ce.test({
        keys: ['*', 'Space', 'Back space'],
        expectedHTML: "*&nbsp;<br>",
        expectedSelectionResolver: (dom) => {
          return {node: dom.childNodes[0], offset: 2} }
      }).then(done).catch(done.fail)
    });

    it("Creates unordered lists with dash", (done) => {
      this.ce.test({
        keys: ['-', 'Space'],
        expectedHTML: "<ul><li></li></ul>",
        expectedSelectionResolver: (dom) => {
          return {node: dom.querySelectorAll("li")[0] } }
      }).then(done).catch(done.fail)
    });

    it("Undoes unordered list creation with backspace", (done) => {
      this.ce.test({
        keys: ['-', 'Space', 'Back space'],
        expectedHTML: "-&nbsp;<br>",
        expectedSelectionResolver: (dom) => {
          return {node: dom.childNodes[0], offset: 2} }
      }).then(done).catch(done.fail)
    });

    // it("create a single item then delete it with backspace", (done) => {
    //   this.ce.test({
    //     keys: ['-', 'Space', 'a', 'Left arrow', 'Back space'],
    //     expectedHTML: "<span style=\"line-height: 1.4;\">a</span><br>",
    //     expectedSelectionResolver: (dom) => {
    //       return {node: dom.childNodes[0], offset: 0} }
    //   }).then(done).catch(done.fail)
    // });
    //
    // it("create a single item then delete it with tab", (done) => {
    //   this.ce.test({
    //     keys: ['-', 'Space', 'a', 'Shift', 'Tab'],
    //     expectedHTML: "<span style=\"line-height: 1.4;\">a</span><br>",
    //     expectedSelectionResolver: (dom) => {
    //       return {node: dom.childNodes[0], offset: 1} }
    //   }).then(done).catch(done.fail)
    // });

  });



  describe('Ensuring popout composer window works', () => {
    it("has main window visible", (done)=> {
      this.app.client.isWindowVisible()
      .then((result)=>{ expect(result).toBe(true) })
      .then(done).catch(done.fail)
    });

    it("has main window focused", (done)=> {
      this.app.client.isWindowFocused()
      .then((result)=>{ expect(result).toBe(true) })
      .then(done).catch(done.fail)
    });

    it("isn't minimized", (done)=> {
      this.app.client.isWindowMinimized()
      .then((result)=>{ expect(result).toBe(false) })
      .then(done).catch(done.fail)
    });

    it("doesn't have the dev tools open", (done)=> {
      this.app.client.isWindowDevToolsOpened()
      .then((result)=>{ expect(result).toBe(false) })
      .then(done).catch(done.fail)
    });

    it("has width", (done)=> {
      this.app.client.getWindowWidth()
      .then((result)=>{ expect(result).toBeGreaterThan(0) })
      .then(done).catch(done.fail)
    });

    it("has height", (done)=> {
      this.app.client.getWindowHeight()
      .then((result)=>{ expect(result).toBeGreaterThan(0) })
      .then(done).catch(done.fail)
    });
  });
});
