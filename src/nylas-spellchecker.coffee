path = require('path')
spellchecker = require('spellchecker')
{remote} = require('electron')
MenuItem = remote.require('menu-item')

class NylasSpellchecker
  constructor: ->
    @languageAvailable = false
    @cache = {}

    lang = navigator.language
    @setLanguage(lang)

  isLanguageAvailable: (lang) =>
    return false unless lang
    dicts = @getAvailableDictionaries()
    return (lang in dicts) or (lang.split(/[-_]/)[0] in dicts) or (lang.replace('_', '-') in dicts) or (lang.replace('-', '_') in dicts)

  isSpelledCorrectly: (args...) => not @isMisspelled(args...)

  setLanguage: (lang="", dict=@_getHunspellDictionary()) ->
    @languageAvailable = @isLanguageAvailable(lang)
    if @languageAvailable
      spellCheck = @isSpelledCorrectly
    else
      spellCheck = -> true

    # Need to default to a valid language so web-frame
    # `setSpellCheckProvder` gets a non empty string
    if lang.length is 0 then lang = "en-US"

    @_setWebframeSpellchecker(lang, spellCheck)

    # On Mac we defer to NSSpellChecker
    # On Windows we use the Windows Spell Check API
    #
    # Both of those automatically provide a set of dictionaries based on
    # the language string.
    #
    # On Windows 10 you can see the dictionaries that are available by
    # looking in: C:\Users\YourName\AppData\Roaming\Microsoft\Spelling
    #
    # The `dict` parameter is ignored by node-spellchecker
    #
    # On Linux and old versions of windows we default back to the hunspell
    # dictionary
    spellchecker.setDictionary(lang, dict)

  # Separate method for testing
  _setWebframeSpellchecker: (lang, spellCheck) ->
    require('electron').webFrame.setSpellCheckProvider(lang, false, {spellCheck})

  # node-spellchecker's method for resolving the builtin hunspell
  # dictionaries for Linux (From
  # https://github.com/atom/node-spellchecker/blob/master/lib/spellchecker.js#L50-L61)
  _getHunspellDictionary: ->
    dict = path.join(require.resolve('spellchecker'), '..', '..', 'vendor', 'hunspell_dictionaries')
    try
      # HACK: Special case being in an asar archive
      unpacked = dict.replace('.asar' + path.sep, '.asar.unpacked' + path.sep)
      if require('fs').statSyncNoException(unpacked)
        dict = unpacked
    catch

    dict

  #### spellchecker methods ####
  setDictionary: (lang, dict) =>
    @setLanguage(lang, dict)

  add: (word) =>
    delete @cache[word]
    spellchecker.add(word)

  isMisspelled: (word) =>
    if @languageAvailable
      @cache[word] ?= spellchecker.isMisspelled(word)
      @cache[word]
    else
      false

  getAvailableDictionaries: ->
    if process.platform is 'linux'
      arr = spellchecker.getAvailableDictionaries()
      if "en_US" not in arr
        arr.push('en_US') # Installed by default in node-spellchecker's vendor directory
      arr
    else
      spellchecker.getAvailableDictionaries() ? []

  getCorrectionsForMisspelling: (args...) =>
    if @languageAvailable
      spellchecker.getCorrectionsForMisspelling(args...)
    else return []

  appendSpellingItemsToMenu: ({menu, word, onCorrect, onDidLearn}) =>
    if @isMisspelled(word)
      corrections = @getCorrectionsForMisspelling(word)
      if corrections.length > 0
        corrections.forEach (correction) =>
          menu.append(new MenuItem({
            label: correction,
            click: -> onCorrect(correction)
          }))
      else
        menu.append(new MenuItem({ label: 'No Guesses Found', enabled: false}))

      menu.append(new MenuItem({ type: 'separator' }))
      menu.append(new MenuItem({
        label: 'Learn Spelling',
        click: =>
          @add(word)
          onDidLearn?(word)
      }))
      menu.append(new MenuItem({ type: 'separator' }))


  Spellchecker: => @

module.exports = new NylasSpellchecker()
