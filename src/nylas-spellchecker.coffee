spellchecker = require('spellchecker')

class NylasSpellchecker
  constructor: ->
    @languageAvailable = false

    lang = navigator.language
    @setLanguage(lang)

  isLanguageAvailable: (lang) =>
    return false unless lang
    dicts = @getAvailableDictionaries()
    return (lang in dicts) or (lang.split(/[-_]/)[0] in dicts)

  isSpelledCorrectly: (args...) => not @isMisspelled(args...)

  setLanguage: (lang) ->
    @languageAvailable = @isLanguageAvailable(lang)
    if @languageAvailable
      spellCheck = @isSpelledCorrectly
    else
      spellCheck = -> true

    @_setWebframeSpellchecker(lang, spellCheck)
    spellchecker.setDictionary(lang)

  # Separate method for testing
  _setWebframeSpellchecker: (lang, spellCheck) ->
    require('web-frame').setSpellCheckProvider(lang, false, {spellCheck})

  #### spellchecker methods ####
  setDictionary: (lang) => @setLanguage(lang)

  add: spellchecker.add

  isMisspelled: (text) =>
    if @languageAvailable then spellchecker.isMisspelled(text)
    else return false

  getAvailableDictionaries: ->
    spellchecker.getAvailableDictionaries() ? []

  getCorrectionsForMisspelling: (args...) =>
    if @languageAvailable
      spellchecker.getCorrectionsForMisspelling(args...)
    else return []

  Spellchecker: => @

module.exports = new NylasSpellchecker
