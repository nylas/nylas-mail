NylasSpellchecker = require '../src/nylas-spellchecker'

describe "NylasSpellchecker", ->
  beforeEach ->
    @spellchecker = NylasSpellchecker
    @fullDictList = ["en_AU", "en_GB", "en_CA", "en_IN", "en", "da", "de", "es", "fr", "it", "Multilingual", "nl", "nb", "pt_BR", "pt_PT", "sv", "tr", "ru"]

  it "can be passed a null language", ->
    @spellchecker.setLanguage()
    expect(@spellchecker.languageAvailable).toBe false

  it "can be passed a null or empty language", ->
    @spellchecker.setLanguage("")
    expect(@spellchecker.languageAvailable).toBe false

  it "accepts null languages", ->
    expect(@spellchecker.isLanguageAvailable()).toBe false

  it "returns false if we can't find the language", ->
    spyOn(@spellchecker, "getAvailableDictionaries").andReturn []
    expect(@spellchecker.isLanguageAvailable("en-US")).toBe false

  it "returns false if we can't find the language", ->
    spyOn(@spellchecker, "getAvailableDictionaries").andReturn @fullDictList
    expect(@spellchecker.isLanguageAvailable("foo")).toBe false

  it "recognizes en-US when en-US is in the list", ->
    spyOn(@spellchecker, "getAvailableDictionaries").andReturn ["en-US"]
    expect(@spellchecker.isLanguageAvailable("en-US")).toBe true

  it "recognizes en-US when only en is in the list", ->
    spyOn(@spellchecker, "getAvailableDictionaries").andReturn @fullDictList
    expect(@spellchecker.isLanguageAvailable("en-US")).toBe true

  it "recognizes en_US when only en is in the list", ->
    spyOn(@spellchecker, "getAvailableDictionaries").andReturn @fullDictList
    expect(@spellchecker.isLanguageAvailable("en_US")).toBe true

  it "recognizes en when only en is in the list", ->
    spyOn(@spellchecker, "getAvailableDictionaries").andReturn @fullDictList
    expect(@spellchecker.isLanguageAvailable("en")).toBe true

  describe "when we don't recognize the language", ->
    beforeEach ->
      spyOn(@spellchecker, "getAvailableDictionaries").andReturn ["foo"]
      spyOn(@spellchecker, "_setWebframeSpellchecker")
      @spellchecker.setLanguage("en-US")

    it "sets `languageAvailable` to false", ->
      expect(@spellchecker.languageAvailable).toBe false

    it "sets the web-frame's spellchecker to always return true", ->
      expect(@spellchecker._setWebframeSpellchecker).toHaveBeenCalled()
      checkFn = @spellchecker._setWebframeSpellchecker.calls[0].args[1]
      expect(checkFn()).toBe true

    it "always says words are spelled correctly", ->
      expect(@spellchecker.isMisspelled()).toBe false
      expect(@spellchecker.isMisspelled("hello")).toBe false
      expect(@spellchecker.isMisspelled("asdf")).toBe false

    it "never provides corrections", ->
      expect(@spellchecker.getCorrectionsForMisspelling()).toEqual []
      expect(@spellchecker.getCorrectionsForMisspelling("hello")).toEqual []
      expect(@spellchecker.getCorrectionsForMisspelling("asdfg")).toEqual []

  describe "when we do recognize the language", ->
    beforeEach ->
      spyOn(@spellchecker, "getAvailableDictionaries").andReturn ["en-US"]
      spyOn(@spellchecker, "_setWebframeSpellchecker")
      @spellchecker.setLanguage("en-US")

    it "sets `languageAvailable` to true", ->
      expect(@spellchecker.languageAvailable).toBe true

    it "it correctly says on the webframe when words are spelled correctly", ->
      @spellchecker.setLanguage("en-US")
      expect(@spellchecker._setWebframeSpellchecker).toHaveBeenCalled()
      checkFn = @spellchecker._setWebframeSpellchecker.calls[0].args[1]
      expect(checkFn("hello")).toBe true
      expect(checkFn("asdfh")).toBe false

    it "correctly knows when english words are mispelled", ->
      expect(@spellchecker.isMisspelled()).toBe false
      expect(@spellchecker.isMisspelled("hello")).toBe false
      expect(@spellchecker.isMisspelled("asdfj")).toBe true

    it "provides options for misspelled words", ->
      expect(@spellchecker.getCorrectionsForMisspelling("")).toEqual []
      # TODO: Determine the reason OS X and/or Windows return an empty array
      # for the string. -mbilker
      if process.platform is 'linux'
        expect(@spellchecker.getCorrectionsForMisspelling("asdfk")).toEqual ['asked', 'acidify', 'Assad']
      else
        expect(@spellchecker.getCorrectionsForMisspelling("asdfk")).toEqual []

    it "still provides options for correctly spelled workds", ->
      expect(@spellchecker.getCorrectionsForMisspelling("hello").length).toBeGreaterThan 1
