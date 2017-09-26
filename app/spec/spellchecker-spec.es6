/* eslint global-require: 0 */
import fs from 'fs';
import { Spellchecker } from 'mailspring-exports';

describe('Spellchecker', function spellcheckerTests() {
  beforeEach(() => {
    // electron-spellchecker is under heavy development, make sure we can still
    // rely on this method
    expect(Spellchecker.handler.handleElectronSpellCheck).toBeDefined();
    this.customDict = '{}';
    spyOn(fs, 'writeFile').andCallFake((path, customDict, cb) => {
      this.customDict = customDict;
      cb();
    });
    spyOn(fs, 'readFile').andCallFake((path, cb) => {
      cb(null, this.customDict);
    });
    // Apparently handleElectronSpellCheck returns !misspelled
    spyOn(Spellchecker.handler, 'handleElectronSpellCheck').andReturn(false);
    Spellchecker.isMisspelledCache = {};
  });

  it('does not call spellchecker when word has already been learned', () => {
    Spellchecker.isMisspelledCache = { mispelled: true };
    const misspelled = Spellchecker.isMisspelled('mispelled');
    expect(misspelled).toBe(true);
    expect(Spellchecker.handler.handleElectronSpellCheck).not.toHaveBeenCalled();
  });

  describe('when a custom word is added', () => {
    this.customWord = 'becaause';

    beforeEach(() => {
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(true);
      Spellchecker.learnWord(this.customWord);
    });

    afterEach(() => {
      Spellchecker.unlearnWord(this.customWord);
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(true);
    });

    it("doesn't think it's misspelled", () => {
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(false);
    });

    it('maintains it across instances', () => {
      const Spellchecker2 = require('../src/spellchecker').default;
      expect(Spellchecker2.isMisspelled(this.customWord)).toEqual(false);
    });
  });
});
