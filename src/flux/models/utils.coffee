_ = require 'underscore'
fs = require('fs-plus')
path = require('path')

tz = Intl.DateTimeFormat().resolvedOptions().timeZone

module.exports =
Utils =
  timeZone: tz

  isHash: (object) ->
    _.isObject(object) and not _.isFunction(object) and not _.isArray(object)

  escapeRegExp: (str) ->
    str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

  # Generates a new RegExp that is great for basic search fields. It
  # checks if the test string is at the start of words
  #
  # See regex explanation and test here:
  # https://regex101.com/r/zG7aW4/2
  wordSearchRegExp: (str="") ->
    new RegExp("((?:^|\\W|$)#{Utils.escapeRegExp(str.trim())})", "ig")

  # Takes an optional customizer. The customizer is passed the key and the
  # new cloned value for that key. The customizer is expected to either
  # modify the value and return it or simply be the identity function.
  deepClone: (object, customizer, stackSeen=[], stackRefs=[]) ->
    return object unless _.isObject(object)
    return object if _.isFunction(object)

    if _.isArray(object)
      # http://perfectionkills.com/how-ecmascript-5-still-does-not-allow-to-subclass-an-array/
      newObject = []
    else
      newObject = Object.create(Object.getPrototypeOf(object))

    # Circular reference check
    seenIndex = stackSeen.indexOf(object)
    if seenIndex >= 0 then return stackRefs[seenIndex]
    stackSeen.push(object); stackRefs.push(newObject)

    # It's important to use getOwnPropertyNames instead of Object.keys to
    # get the non-enumerable items as well.
    for key in Object.getOwnPropertyNames(object)
      newVal = Utils.deepClone(object[key], customizer, stackSeen, stackRefs)
      if _.isFunction(customizer)
        newObject[key] = customizer(key, newVal)
      else
        newObject[key] = newVal
    return newObject

  toSet: (arr=[]) ->
    set = {}
    set[item] = true for item in arr
    return set

  # Given a File object or uploadData of an uploading file object,
  # determine if it looks like an image
  looksLikeImage: (file={}) ->
    name = file.filename ? file.fileName ? file.name ? ""
    size = file.size ? file.fileSize ? 0
    ext = path.extname(name).toLowerCase()
    extensions = ['.jpg', '.bmp', '.gif', '.png', '.jpeg']

    return ext in extensions and size > 512 and size < 1024*1024*10


  looksLikeGmailInvite: (message={}) ->
    idx = message.body.search('itemtype="http://schema.org/Event"')
    if idx == -1
      return false
    return true


  # Escapes potentially dangerous html characters
  # This code is lifted from Angular.js
  # See their specs here:
  # https://github.com/angular/angular.js/blob/master/test/ngSanitize/sanitizeSpec.js
  # And the original source here: https://github.com/angular/angular.js/blob/master/src/ngSanitize/sanitize.js#L451
  encodeHTMLEntities: (value) ->
    SURROGATE_PAIR_REGEXP = /[\uD800-\uDBFF][\uDC00-\uDFFF]/g
    pairFix = (value) ->
      hi = value.charCodeAt(0)
      low = value.charCodeAt(1)
      return '&#' + (((hi - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000) + ';'

    # Match everything outside of normal chars and " (quote character)
    NON_ALPHANUMERIC_REGEXP = /([^\#-~| |!])/g
    alphaFix = (value) -> '&#' + value.charCodeAt(0) + ';'

    value.replace(/&/g, '&amp;').
          replace(SURROGATE_PAIR_REGEXP, pairFix).
          replace(NON_ALPHANUMERIC_REGEXP, alphaFix).
          replace(/</g, '&lt;').
          replace(/>/g, '&gt;')

  modelClassMap: ->
    return Utils._modelClassMap if Utils._modelClassMap

    Thread = require './thread'
    Message = require './message'
    Namespace = require './namespace'
    Label = require './label'
    Folder = require './folder'
    File = require './file'
    Contact = require './contact'
    LocalLink = require './local-link'
    Event = require './event'
    Calendar = require './calendar'
    Metadata = require './metadata'

    ## TODO move to inside of individual Salesforce package. See https://trello.com/c/tLAGLyeb/246-move-salesforce-models-into-individual-package-db-models-for-packages-various-refactors
    SalesforceTask = require './salesforce-task'
    SalesforceObject = require './salesforce-object'
    SalesforceSchema = require './salesforce-schema'
    SalesforceAssociation = require './salesforce-association'
    SalesforceSearchResult = require './salesforce-search-result'

    SyncbackDraftTask = require '../tasks/syncback-draft'
    SendDraftTask = require '../tasks/send-draft'
    DestroyDraftTask = require '../tasks/destroy-draft'

    FileUploadTask = require '../tasks/file-upload-task'
    EventRSVP = require '../tasks/event-rsvp'
    ChangeLabelsTask = require '../tasks/change-labels-task'
    ChangeFolderTask = require '../tasks/change-folder-task'
    MarkMessageReadTask = require '../tasks/mark-message-read'

    Utils._modelClassMap = {
      'thread': Thread
      'message': Message
      'draft': Message
      'contact': Contact
      'namespace': Namespace
      'file': File
      'label': Label
      'folder': Folder
      'locallink': LocalLink
      'calendar': Calendar
      'event': Event
      'metadata': Metadata
      'salesforceschema': SalesforceSchema
      'salesforceobject': SalesforceObject
      'salesforceassociation': SalesforceAssociation
      'salesforcesearchresult': SalesforceSearchResult
      'salesforcetask': SalesforceTask

      'MarkMessageReadTask': MarkMessageReadTask
      'ChangeLabelsTask': ChangeLabelsTask
      'ChangeFolderTask': ChangeFolderTask
      'SendDraftTask': SendDraftTask
      'SyncbackDraftTask': SyncbackDraftTask
      'DestroyDraftTask': DestroyDraftTask
      'FileUploadTask': FileUploadTask
      'EventRSVP': EventRSVP
    }
    Utils._modelClassMap

  modelFromJSON: (json) ->
    # These imports can't go at the top of the file
    # because they cause circular requires
    klass = Utils.modelClassMap()[json.object]
    throw (new Error "Unsure of how to inflate #{JSON.stringify(json)}") unless klass
    throw (new Error "Cannot inflate #{json.object}, require did not return constructor") unless klass instanceof Function
    object = new klass()
    object.fromJSON(json)
    object

  modelFreeze: (o) ->
    Object.freeze(o)
    for key, prop of o
      continue unless o.hasOwnProperty(key)
      continue unless typeof prop is 'object' and prop isnt null
      continue if Object.isFrozen(prop)
      Utils.modelFreeze(prop)

  modelReviver: (k, v) ->
    return v if k == ""
    v = Utils.modelFromJSON(v) if (v instanceof Object && v['object'])
    v

  generateTempId: ->
    s4 = ->
      Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
    'local-' + s4() + s4() + '-' + s4()

  isTempId: (id) ->
    return false unless id
    id[0..5] == 'local-'

  tableNameForJoin: (primaryKlass, secondaryKlass) ->
    "#{primaryKlass.name}-#{secondaryKlass.name}"

  imageNamed: (resourcePath, fullname) ->
    [name, ext] = fullname.split('.')

    Utils.images ?= {}
    if not Utils.images[resourcePath]?
      imagesPath = path.join(resourcePath, 'static', 'images')
      files = fs.listTreeSync(imagesPath)

      Utils.images[resourcePath] ?= {}
      for file in files
        # On Windows, we get paths like C:\images\compose.png, but Chromium doesn't
        # accept the backward slashes. Convert to C:/images/compose.png
        file = file.replace(/\\/g, '/')
        Utils.images[resourcePath][path.basename(file)] = file

    if window.devicePixelRatio > 1
      return Utils.images[resourcePath]["#{name}@2x.#{ext}"] ? Utils.images[resourcePath][fullname] ? Utils.images[resourcePath]["#{name}@1x.#{ext}"]
    else
      return Utils.images[resourcePath]["#{name}@1x.#{ext}"] ? Utils.images[resourcePath][fullname] ? Utils.images[resourcePath]["#{name}@2x.#{ext}"]

  subjectWithPrefix: (subject, prefix) ->
    if subject.search(/fwd:/i) is 0
      return subject.replace(/fwd:/i, prefix)
    else if subject.search(/re:/i) is 0
      return subject.replace(/re:/i, prefix)
    else
      return "#{prefix} #{subject}"

  # Returns true if the message contains "Forwarded" or "Fwd" in the first
  # 250 characters.  A strong indicator that the quoted text should be
  # shown. Needs to be limited to first 250 to prevent replies to
  # forwarded messages from also being expanded.
  isForwardedMessage: ({body, subject} = {}) ->
    bodyForwarded = false
    bodyFwd = false
    subjectFwd = false

    if body
      indexForwarded = body.search(/forwarded/i)
      bodyForwarded = indexForwarded >= 0 and indexForwarded < 250
      indexFwd = body.search(/fwd/i)
      bodyFwd = indexFwd >= 0 and indexFwd < 250
    if subject
      subjectFwd = subject[0...3].toLowerCase() is "fwd"

    return bodyForwarded or bodyFwd or subjectFwd

  # True of all arguments have the same domains
  emailsHaveSameDomain: (args...) ->
    return false if args.length < 2
    domains = args.map (email="") ->
      _.last(email.toLowerCase().trim().split("@"))
    toMatch = domains[0]
    return _.every(domains, (domain) -> domain.length > 0 and toMatch is domain)

  emailHasCommonDomain: (email="") ->
    domain = _.last(email.toLowerCase().trim().split("@"))
    return (Utils.commonDomains[domain] ? false)

  isEqualReact: (a, b, options={}) ->
    options.functionsAreEqual = true
    options.ignoreKeys = (options.ignoreKeys ? []).push("localId")
    Utils.isEqual(a, b, options)

  # Customized version of Underscore 1.8.2's isEqual function
  # You can pass the following options:
  #   - functionsAreEqual: if true then all functions are equal
  #   - keysToIgnore: an array of object keys to ignore checks on
  #   - logWhenFalse: logs when isEqual returns false
  isEqual: (a, b, options={}) ->
    value = Utils._isEqual(a, b, [], [], options)
    if options.logWhenFalse
      if value is false then console.log "isEqual is false", a, b, options
      return value
    else
    return value

  _isEqual: (a, b, aStack, bStack, options={}) ->
    # Identical objects are equal. `0 is -0`, but they aren't identical.
    # See the [Harmony `egal`
    # proposal](http://wiki.ecmascript.org/doku.php?id=harmony:egal).
    if (a is b) then return a isnt 0 or 1 / a is 1 / b
    # A strict comparison is necessary because `null == undefined`.
    if (a == null or b == null) then return a is b
    # Unwrap any wrapped objects.
    if (a?._wrapped?) then a = a._wrapped
    if (b?._wrapped?) then b = b._wrapped

    if options.functionsAreEqual
      if _.isFunction(a) and _.isFunction(b) then return true

    # Compare `[[Class]]` names.
    className = toString.call(a)
    if (className isnt toString.call(b)) then return false
    switch (className)
      # Strings, numbers, regular expressions, dates, and booleans are
      # compared by value.
      # RegExps are coerced to strings for comparison (Note: '' + /a/i is '/a/i')
      when '[object RegExp]', '[object String]'
        # Primitives and their corresponding object wrappers are equivalent;
        # thus, `"5"` is equivalent to `new String("5")`.
        return '' + a is '' + b
      when '[object Number]'
        # `NaN`s are equivalent, but non-reflexive.
        # Object(NaN) is equivalent to NaN
        if (+a isnt +a) then return +b isnt +b
        # An `egal` comparison is performed for other numeric values.
        return if +a is 0 then 1 / +a is 1 / b else +a is +b
      when '[object Date]', '[object Boolean]'
        # Coerce dates and booleans to numeric primitive values. Dates are
        # compared by their millisecond representations. Note that invalid
        # dates with millisecond representations of `NaN` are not
        # equivalent.
        return +a is +b

    areArrays = className is '[object Array]'
    if (!areArrays)
      if (typeof a != 'object' or typeof b != 'object') then return false

      # Objects with different constructors are not equivalent, but
      # `Object`s or `Array`s from different frames are.
      aCtor = a.constructor
      bCtor = b.constructor
      if (aCtor isnt bCtor && !(_.isFunction(aCtor) && aCtor instanceof aCtor &&
                               _.isFunction(bCtor) && bCtor instanceof bCtor) && ('constructor' of a && 'constructor' of b))
        return false
    # Assume equality for cyclic structures. The algorithm for detecting cyclic
    # structures is adapted from ES 5.1 section 15.12.3, abstract operation `JO`.

    # Initializing stack of traversed objects.
    # It's done here since we only need them for objects and arrays comparison.
    aStack = aStack ? []
    bStack = bStack ? []
    length = aStack.length
    while length--
      # Linear search. Performance is inversely proportional to the number of
      # unique nested structures.
      if (aStack[length] is a) then return bStack[length] is b

    # Add the first object to the stack of traversed objects.
    aStack.push(a)
    bStack.push(b)

    # Recursively compare objects and arrays.
    if (areArrays)
      # Compare array lengths to determine if a deep comparison is necessary.
      length = a.length
      if (length isnt b.length) then return false
        # Deep compare the contents, ignoring non-numeric properties.
      while (length--)
        if (!Utils._isEqual(a[length], b[length], aStack, bStack, options)) then return false
    else
      # Deep compare objects.
      key = undefined
      keys = _.keys(a)
      length = keys.length
      # Ensure that both objects contain the same number of properties
      # before comparing deep equality.
      if (_.keys(b).length isnt length) then return false
      keysToIgnore = {}
      if options.ignoreKeys and _.isArray(options.ignoreKeys)
        keysToIgnore[key] = true for key in options.ignoreKeys
      while length--
        # Deep compare each member
        key = keys[length]
        if key of keysToIgnore then continue
        if (!(_.has(b, key) && Utils._isEqual(a[key], b[key], aStack, bStack, options)))
          return false
    # Remove the first object from the stack of traversed objects.
    aStack.pop()
    bStack.pop()
    return true

  # https://github.com/mailcheck/mailcheck/wiki/list-of-popular-domains
  # As a hash for instant lookup.
  commonDomains:
    "aol.com": true
    "att.net": true
    "comcast.net": true
    "facebook.com": true
    "gmail.com": true
    "gmx.com": true
    "googlemail.com": true
    "google.com": true
    "hotmail.com": true
    "hotmail.co.uk": true
    "mac.com": true
    "me.com": true
    "mail.com": true
    "msn.com": true
    "live.com": true
    "sbcglobal.net": true
    "verizon.net": true
    "yahoo.com": true
    "yahoo.co.uk": true
    "email.com": true
    "games.com": true
    "gmx.net": true
    "hush.com": true
    "hushmail.com": true
    "inbox.com": true
    "lavabit.com": true
    "love.com": true
    "pobox.com": true
    "rocketmail.com": true
    "safe-mail.net": true
    "wow.com": true
    "ygm.com": true
    "ymail.com": true
    "zoho.com": true
    "fastmail.fm": true
    "bellsouth.net": true
    "charter.net": true
    "cox.net": true
    "earthlink.net": true
    "juno.com": true
    "btinternet.com": true
    "virginmedia.com": true
    "blueyonder.co.uk": true
    "freeserve.co.uk": true
    "live.co.uk": true
    "ntlworld.com": true
    "o2.co.uk": true
    "orange.net": true
    "sky.com": true
    "talktalk.co.uk": true
    "tiscali.co.uk": true
    "virgin.net": true
    "wanadoo.co.uk": true
    "bt.com": true
    "sina.com": true
    "qq.com": true
    "naver.com": true
    "hanmail.net": true
    "daum.net": true
    "nate.com": true
    "yahoo.co.jp": true
    "yahoo.co.kr": true
    "yahoo.co.id": true
    "yahoo.co.in": true
    "yahoo.com.sg": true
    "yahoo.com.ph": true
    "hotmail.fr": true
    "live.fr": true
    "laposte.net": true
    "yahoo.fr": true
    "wanadoo.fr": true
    "orange.fr": true
    "gmx.fr": true
    "sfr.fr": true
    "neuf.fr": true
    "free.fr": true
    "gmx.de": true
    "hotmail.de": true
    "live.de": true
    "online.de": true
    "t-online.de": true
    "web.de": true
    "yahoo.de": true
    "mail.ru": true
    "rambler.ru": true
    "yandex.ru": true
    "hotmail.be": true
    "live.be": true
    "skynet.be": true
    "voo.be": true
    "tvcablenet.be": true
    "hotmail.com.ar": true
    "live.com.ar": true
    "yahoo.com.ar": true
    "fibertel.com.ar": true
    "speedy.com.ar": true
    "arnet.com.ar": true
    "hotmail.com": true
    "gmail.com": true
    "yahoo.com.mx": true
    "live.com.mx": true
    "yahoo.com": true
    "hotmail.es": true
    "live.com": true
    "hotmail.com.mx": true
    "prodigy.net.mx": true
    "msn.com": true

  # This method ensures that the provided function `fn` is only executing
  # once at any given time. `fn` should have the following signature:
  #
  # (finished, reinvoked, arg1, arg2, ...)
  #
  # During execution, the function can call reinvoked() to see if
  # it has been called again since it was invoked. When it stops
  # or finishes execution, it should call finished()
  #
  # If the wrapped function is called again while `fn` is still executing,
  # another invocation of the function is queued up. The paramMerge
  # function allows you to control the params that are passed to
  # the next invocation.
  #
  # For example,
  #
  # fetchFromCache({shallow: true})
  #
  # fetchFromCache({shallow: true})
  #  -- will be executed once the initial call finishes
  #
  # fetchFromCache({})
  #  -- `paramMerge` is called with `[{}]` and `[{shallow:true}]`. At this
  #     point it should return `[{}]` since calling fetchFromCache with no
  #     options is a more significant refresh.
  #
  ensureSerialExecution: (fn, paramMerge) ->
    fnRun = null
    fnReinvoked = ->
      fn.next
    fnFinished = ->
      fn.executing = false
      if fn.next
        args = fn.next
        fn.next = null
        fnRun(args...)
    fnRun = ->
      if fn.executing
        if fn.next
          fn.next = paramMerge(fn.next, arguments)
        else
          fn.next = arguments
      else
        fn.executing = true
        fn.apply(@, [fnFinished, fnReinvoked, arguments...])
    fnRun
