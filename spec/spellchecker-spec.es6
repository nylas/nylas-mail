/* eslint global-require: 0 */
import {Spellchecker} from 'nylas-exports';

describe("Spellchecker", function spellcheckerTests() {
  beforeEach(() => {
    Spellchecker.handler.switchLanguage('en-US'); // Start with US English
  });

  [
    {name: "French", code: "fr", sentence: "Ceci est une phrase avec quelques mots."},
    {name: "German", code: "de", sentence: "Das ist ein Satz mit einigen Worten."},
    {name: "Italian", code: "it", sentence: "Questa è una frase con alcune parole."},
    {name: "Russian", code: "ru", sentence: "Это предложение с некоторыми словами."},
    {name: "Spanish", code: "es", sentence: "Esta es una oración con algunas palabras."},
    // English shouldn't be first since we start out as English.
    {name: "English", code: "en", sentence: "This is a sentence with some words."},
  ].forEach(({name, code, sentence}) => {
    it(`properly detects language when given a full sentence (${name})`, async () => {
      // Note, on Linux, calling provideHintText can result in a Hunspell
      // dictionary being downloaded. Typically this is fast but it causes
      // intermittent failures.
      if (process.env.TRAVIS && process.platform === 'linux') {
        expect(true).toEqual(true);
        return;
      }

      process.nextTick(() => advanceClock(20));
      const lang = await Spellchecker.handler.detectLanguageForText(sentence);
      expect(lang).toBe(code)
    });
  });

  it("knows whether a word is misspelled or not", () => {
    const correctlySpelled = ["hello", "world", "create", "goodbye", "regards"]
    const misspelled = ["mispelled", "particularily", "kelfiekd", "adlkdgiekdl"]
    for (const word of correctlySpelled) {
      expect(Spellchecker.isMisspelled(word)).toEqual(false);
    }
    for (const word of misspelled) {
      expect(Spellchecker.isMisspelled(word)).toEqual(true);
    }
  });

  it("provides suggestions for misspelled words", () => {
    const suggestions = Spellchecker.handler.currentSpellchecker.getCorrectionsForMisspelling("mispelled")
    expect(suggestions.length > 0).toEqual(true);
    expect(suggestions[0]).toEqual('misspelled');
  })

  describe("when a custom word is added", () => {
    this.customWord = "becaause"

    beforeEach(() => {
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(true)
      Spellchecker.learnWord(this.customWord);
    })

    afterEach(() => {
      Spellchecker.unlearnWord(this.customWord);
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(true)
    })

    it("doesn't think it's misspelled", () => {
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(false)
    })

    it("maintains it when switching languages", () => {
      Spellchecker.handler.switchLanguage("de-DE")
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(false);
      Spellchecker.handler.switchLanguage("en-US")
      expect(Spellchecker.isMisspelled(this.customWord)).toEqual(false);
    })

    it("maintains it across instances", () => {
      const Spellchecker2 = require("../src/spellchecker").default;
      expect(Spellchecker2.isMisspelled(this.customWord)).toEqual(false);
    })
  })
});
