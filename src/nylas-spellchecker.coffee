path = require('path')

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

  setLanguage: (lang="", dict=@_getDictionaryPath()) ->
    @languageAvailable = @isLanguageAvailable(lang)
    if @languageAvailable or process.platform is 'linux'
      spellCheck = @isSpelledCorrectly
    else
      spellCheck = -> true

    # Need to default to a valid language so web-frame
    # `setSpellCheckProvder` gets a non empty string
    if lang.length is 0 then lang = "en-US"

    @_setWebframeSpellchecker(lang, spellCheck)
    spellchecker.setDictionary(lang, dict)

  # Separate method for testing
  _setWebframeSpellchecker: (lang, spellCheck) ->
    require('web-frame').setSpellCheckProvider(lang, false, {spellCheck})

  # node-spellchecker's method for resolving the builtin hunspell dictionaries for Linux
  # (From https://github.com/atom/node-spellchecker/blob/master/lib/spellchecker.js#L50-L61)
  _getDictionaryPath: ->
    dict = path.join(require.resolve('spellchecker'), '..', '..', 'vendor', 'hunspell_dictionaries')
    try
      # HACK: Special case being in an asar archive
      unpacked = dict.replace('.asar' + path.sep, '.asar.unpacked' + path.sep)
      if require('fs').statSyncNoException(unpacked)
        dict = unpacked
    catch

    dict

  #### spellchecker methods ####
  setDictionary: (lang, dict) => @setLanguage(lang, dict)

  add: spellchecker.add

  isMisspelled: (text) =>
    if @languageAvailable or process.platform is 'linux'
      spellchecker.isMisspelled(text)
    else
      return false

  getAvailableDictionaries: ->
    spellchecker.getAvailableDictionaries() ? []

  getCorrectionsForMisspelling: (args...) =>
    if @languageAvailable or process.platform is 'linux'
      spellchecker.getCorrectionsForMisspelling(args...)
    else return []

  Spellchecker: => @

module.exports = new NylasSpellchecker
