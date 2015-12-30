import N1Launcher from './helpers/n1-launcher';
import ContenteditableTestHarness from './helpers/contenteditable-test-harness.es6';

fdescribe('Contenteditable Integration Spec', function() {
  beforeAll((done)=>{
    this.app = new N1Launcher(['--dev']);
    this.app.popoutComposerWindowReady().finally(done);
  });

  beforeEach((done) => {
    this.ce = new ContenteditableTestHarness(this.app.client);
    this.ce.init().finally(done);
  });

  afterAll((done)=> {
    if (this.app && this.app.isRunning()) {
      this.app.stop().then(done);
    } else {
      done();
    }
  });

  describe('Manipulating Lists', () => {
    it('Creates ordered lists', (done)=> {
      this.ce.test({
        keys: ['1', '.', 'Space'],
        expectedHTML: '<ol><li></li></ol>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[0],
          };
        },
      }).then(done).catch(done.fail);
    });

    it('Undoes ordered list creation with backspace', (done) => {
      this.ce.test({
        keys: ['1', '.', 'Space', 'Back space'],
        expectedHTML: '1.&nbsp;<br>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.childNodes[0], offset: 3,
          };
        },
      }).then(done).catch(done.fail);
    });

    it('Creates unordered lists with star', (done) => {
      this.ce.test({
        keys: ['*', 'Space'],
        expectedHTML: '<ul><li></li></ul>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[0],
          };
        },
      }).then(done).catch(done.fail);
    });

    it('Undoes unordered list creation with backspace', (done) => {
      this.ce.test({
        keys: ['*', 'Space', 'Back space'],
        expectedHTML: '*&nbsp;<br>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.childNodes[0], offset: 2,
          };
        },
      }).then(done).catch(done.fail);
    });

    it('Creates unordered lists with dash', (done) => {
      this.ce.test({
        keys: ['-', 'Space'],
        expectedHTML: '<ul><li></li></ul>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[0],
          };
        },
      }).then(done).catch(done.fail);
    });

    it('Undoes unordered list creation with backspace', (done) => {
      this.ce.test({
        keys: ['-', 'Space', 'Back space'],
        expectedHTML: '-&nbsp;<br>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.childNodes[0], offset: 2,
          };
        },
      }).then(done).catch(done.fail);
    });
  });

  describe('When creating two items in a list', () => {
    beforeEach(() => {
      this.twoItemUl = ['-', 'Space', 'a', 'Return', 'b'];
      this.twoItemOl = ['1', '.', 'Space', 'a', 'Return', 'b'];
    });

    it('creates two ordered items with enter at end', (done) => {
      this.ce.test({
        keys: this.twoItemUl,
        expectedHTML: '<ul><li>a</li><li>b</li></ul>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[1].childNodes[0],
            offset: 1,
          };
        },
      }).then(done).catch(done.fail);
    });

    it('creates two bullet items with enter at end', (done) => {
      this.ce.test({
        keys: this.twoItemOl,
        expectedHTML: '<ol><li>a</li><li>b</li></ol>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[1].childNodes[0],
            offset: 1,
          };
        },
      }).then(done).catch(done.fail);
    });

    it('outdents the first item when backspacing from the start', (done) => {
      this.ce.test({
        keys: this.twoItemOl.concat(['Up arrow', 'Left arrow', 'Back space']),
        expectedHTML: '<span style="line-height: 1.4;">a</span><br><ol><li>b</li></ol>',
        expectedSelectionResolver: (dom) => {
          // NOTE: This is being serialized and run in the app process by
          // Selenium
          const {DOMUtils} = require('nylas-exports');
          return {
            node: DOMUtils.findFirstTextNode(dom),
            offset: 0,
          };
        },
      }).then(done).catch(done.fail);
    });

    it('outdents the last item when backspacing from the start', (done) => {
      this.ce.test({
        keys: this.twoItemOl.concat(['Left arrow', 'Back space']),
        expectedHTML: '<ol><li>a</li></ol><span style="line-height: 1.4;">b</span><br>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelector('span').childNodes[0],
            offset: 0,
          };
        },
      }).then(done).catch(done.fail);
    });

  //   xit "backspace from the start of the 1st item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'up', 'backspace']
  //
  //   xit "backspace from the start of the 2nd item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'backspace']
  //
  //   xit "shift-tab from the start of the 1st item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'up', 'shift-tab']
  //
  //   xit "shift-tab from the start of the 2nd item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'shift-tab']
  //
  //   xit "shift-tab from the end of the 1st item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['up', 'shift-tab']
  //
  //   xit "shift-tab from the end of the 2nd item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['shift-tab']
  //
  //   xit "backspace from the end of the 1st item doesn't outdent", ->
  //     @ce.keys @twoItemKeys.concat ['up', 'backspace']
  //
  //   xit "backspace from the end of the 2nd item doesn't outdent", ->
  //     @ce.keys @twoItemKeys.concat ['backspace']
  });

  describe('when creating a list within a list', ()=> {
    beforeEach(() => {
      this.list = ['-', 'Space'];
    });

    it('indents list once', (done)=> {
      this.ce.test({
        keys: this.list.concat(this.list).concat(['a']),
        expectedHTML: '<ul><ul><li>a</li></ul></ul>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[0].childNodes[0],
          };
        },
      }).then(done).catch(done.fail);
    });

    it('indents list twice', (done)=> {
      this.ce.test({
        keys: this.list.concat(this.list).concat(this.list).concat(['a']),
        expectedHTML: '<ul><ul><ul><li>a</li></ul></ul></ul>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[0].childNodes[0],
          };
        },
      }).then(done).catch(done.fail);
    });
  });

  describe('When auto-concatenating lists', () => {
    beforeEach(() => {
      this.threeItemUl = ['-', 'Space', 'a', 'Return', 'b', 'Return', 'c'];
      this.threeItemOl = ['1', '.', 'Space', 'a', 'Return', 'b', 'Return', 'c'];
      this.deleteMiddle = ['Up arrow', 'Back space', 'Back space', 'Back space'];
    });

    it('concatenates adjacent unordered lists', (done) => {
      this.ce.test({
        keys: this.threeItemUl.concat(this.deleteMiddle),
        expectedHTML: '<ul><li>a</li><li>c</li></ul>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[0].childNodes[0],
            offset: 1,
          };
        },
      }).then(done).catch(done.fail);
    });

    it('concatenates adjacent ordered lists', (done) => {
      this.ce.test({
        keys: this.threeItemOl.concat(this.deleteMiddle),
        expectedHTML: '<ol><li>a</li><li>c</li></ol>',
        expectedSelectionResolver: (dom) => {
          return {
            node: dom.querySelectorAll('li')[0].childNodes[0],
            offset: 1,
          };
        },
      }).then(done).catch(done.fail);
    });
  });

  // describe "when creating two items in a list", ->
  //   beforeEach ->
  //     @twoItemKeys = ['-', 'Space', 'a', 'Return', 'b']
  //
  //   it "creates two items with enter at end", -> waitsForPromise =>
  //     @ce.keys(@twoItemKeys).then =>
  //       @ce.expectHTML "<ul><li>a</li><li>b</li></ul>"
  //       @ce.expectSelection (dom) ->
  //         node: dom.querySelectorAll('li')[1].childNodes[0]
  //         offset: 1
  //
  //   xit "backspace from the start of the 1st item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'up', 'backspace']
  //
  //   xit "backspace from the start of the 2nd item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'backspace']
  //
  //   xit "shift-tab from the start of the 1st item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'up', 'shift-tab']
  //
  //   xit "shift-tab from the start of the 2nd item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['left', 'shift-tab']
  //
  //   xit "shift-tab from the end of the 1st item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['up', 'shift-tab']
  //
  //   xit "shift-tab from the end of the 2nd item outdents", ->
  //     @ce.keys @twoItemKeys.concat ['shift-tab']
  //
  //   xit "backspace from the end of the 1st item doesn't outdent", ->
  //     @ce.keys @twoItemKeys.concat ['up', 'backspace']
  //
  //   xit "backspace from the end of the 2nd item doesn't outdent", ->
  //     @ce.keys @twoItemKeys.concat ['backspace']
  //
  // xdescribe "multi-depth bullets", ->
  //   it "creates multi level bullet when tabbed in", ->
  //     @ce.keys ['-', ' ', 'a', 'tab']
  //
  //   it "creates multi level bullet when tabbed in", ->
  //     @ce.keys ['-', ' ', 'tab', 'a']
  //
  //   it "returns to single level bullet on backspace", ->
  //     @ce.keys ['-', ' ', 'a', 'tab', 'left', 'backspace']
  //
  //   it "returns to single level bullet on shift-tab", ->
  //     @ce.keys ['-', ' ', 'a', 'tab', 'shift-tab']


  describe('Ensuring popout composer window works', () => {
    it('has main window visible', (done)=> {
      this.app.client.isWindowVisible()
      .then((result)=> expect(result).toBe(true) )
      .then(done).catch(done.fail);
    });

    it('has main window focused', (done)=> {
      this.app.client.isWindowFocused()
      .then((result)=> expect(result).toBe(true) )
      .then(done).catch(done.fail);
    });

    it('is not minimized', (done)=> {
      this.app.client.isWindowMinimized()
      .then((result)=> expect(result).toBe(false) )
      .then(done).catch(done.fail);
    });

    it('does not have the dev tools open', (done)=> {
      this.app.client.isWindowDevToolsOpened()
      .then((result)=> expect(result).toBe(false) )
      .then(done).catch(done.fail);
    });

    it('has width', (done)=> {
      this.app.client.getWindowWidth()
      .then((result)=> expect(result).toBeGreaterThan(0) )
      .then(done).catch(done.fail);
    });

    it('has height', (done)=> {
      this.app.client.getWindowHeight()
      .then((result)=> expect(result).toBeGreaterThan(0) )
      .then(done).catch(done.fail);
    });
  });
});
