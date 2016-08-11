_ = require 'underscore'
fs = require('fs-plus')
path = require('path')
moment = require('moment-timezone')

DefaultResourcePath = null
TaskRegistry = require('../../task-registry').default
DatabaseObjectRegistry = require('../../database-object-registry').default

imageData = null

module.exports =
Utils =
  waitFor: (latch, options = {}) ->
    timeout = options.timeout || 400
    expire = Date.now() + timeout
    return new Promise (resolve, reject) ->
      attempt = ->
        if Date.now() > expire
          return reject(new Error("Utils.waitFor hit timeout (#{timeout}ms) without firing."))
        if latch()
          return resolve()
        window.requestAnimationFrame(attempt)
      attempt()

  showIconForAttachments: (files) ->
    return false unless files instanceof Array
    return files.find (f) -> !f.contentId or f.size > 12 * 1024

  extractTextFromHtml: (html, {maxLength} = {}) ->
    if (html ? "").trim().length is 0 then return ""
    if maxLength and html.length > maxLength
      html = html.slice(0, maxLength)
    (new DOMParser()).parseFromString(html, "text/html").body.innerText

  registeredObjectReviver: (k,v) ->
    type = v?.__constructorName
    return v unless type

    if DatabaseObjectRegistry.isInRegistry(type)
      return DatabaseObjectRegistry.deserialize(type, v)

    if TaskRegistry.isInRegistry(type)
      return TaskRegistry.deserialize(type, v)

    return v

  registeredObjectReplacer: (k, v) ->
    if _.isObject(v)
      type = this[k].constructor.name
      if DatabaseObjectRegistry.isInRegistry(type) or TaskRegistry.isInRegistry(type)
        v.__constructorName = type
    return v

  fastOmit: (props, without) ->
    otherProps = Object.assign({}, props)
    delete otherProps[w] for w in without
    otherProps

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
  # determine if it looks like an image and is in the size range for previews
  shouldDisplayAsImage: (file={}) ->
    name = file.filename ? file.fileName ? file.name ? ""
    size = file.size ? file.fileSize ? 0
    ext = path.extname(name).toLowerCase()
    extensions = ['.jpg', '.bmp', '.gif', '.png', '.jpeg']

    return ext in extensions and size > 512 and size < 1024*1024*5


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

  modelFreeze: (o) ->
    Object.freeze(o)
    Object.getOwnPropertyNames(o).forEach (key) ->
      val = o[key]
      if typeof val is 'object' and val isnt null and not Object.isFrozen(val)
        Utils.modelFreeze(val)

  generateTempId: ->
    s4 = ->
      Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
    'local-' + s4() + s4() + '-' + s4()

  generateFakeServerId: ->
    s5 = ->
      Math.floor((1 + Math.random()) * 0x10000000).toString(36).substring(1)
    return s5() + s5() + s5() + s5() + s5()

  isTempId: (id) ->
    return false unless id and _.isString(id)
    id[0..5] is 'local-'

  tableNameForJoin: (primaryKlass, secondaryKlass) ->
    "#{primaryKlass.name}#{secondaryKlass.name}"

  imageNamed: (fullname, resourcePath) ->
    [name, ext] = fullname.split('.')

    DefaultResourcePath ?= NylasEnv.getLoadSettings().resourcePath
    resourcePath ?= DefaultResourcePath

    if not imageData
      imageData = NylasEnv.fileListCache().imageData ? "{}"
      Utils.images = JSON.parse(imageData) ? {}

    if not Utils?.images?[resourcePath]
      Utils.images ?= {}
      Utils.images[resourcePath] ?= {}
      imagesPath = path.join(resourcePath, 'static', 'images')
      files = fs.listTreeSync(imagesPath)
      for file in files
        # On Windows, we get paths like C:\images\compose.png, but
        # Chromium doesn't accept the backward slashes. Convert to
        # C:/images/compose.png
        file = file.replace(/\\/g, '/')
        basename = path.basename(file)
        Utils.images[resourcePath][path.basename(file)] = file
      NylasEnv.fileListCache().imageData = JSON.stringify(Utils.images)

    plat = process.platform ? ""
    ratio = window.devicePixelRatio ? 1

    return Utils.images[resourcePath]["#{name}-#{plat}@#{ratio}x.#{ext}"] ?
           Utils.images[resourcePath]["#{name}@#{ratio}x.#{ext}"] ?
           Utils.images[resourcePath]["#{name}-#{plat}.#{ext}"] ?
           Utils.images[resourcePath]["#{name}.#{ext}"] ?
           Utils.images[resourcePath]["#{name}-#{plat}@2x.#{ext}"] ?
           Utils.images[resourcePath]["#{name}@2x.#{ext}"] ?
           Utils.images[resourcePath]["#{name}-#{plat}@1x.#{ext}"] ?
           Utils.images[resourcePath]["#{name}@1x.#{ext}"]

  subjectWithPrefix: (subject, prefix) ->
    if subject.search(/fwd:/i) is 0
      return subject.replace(/fwd:/i, prefix)
    else if subject.search(/re:/i) is 0
      return subject.replace(/re:/i, prefix)
    else
      return "#{prefix} #{subject}"

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

  # This looks for and removes plus-ing, it taks a VERY liberal approach
  # to match an email address. We'd rather let false positives through.
  toEquivalentEmailForm: (email) ->
    # https://regex101.com/r/iS7kD5/1
    localPart1 = /([^+]+?)[+@].*/gi.exec(email)?[1] ? ""

    # https://regex101.com/r/iS7kD5/2
    domainPart1 = /@(.+)/gi.exec(email)?[1] ? ""

    email = "#{localPart1}@#{domainPart1}".trim().toLowerCase()
    return email

  emailIsEquivalent: (email1="", email2="") ->
    return true if email1 is email2
    email1 = Utils.toEquivalentEmailForm(email1)
    email2 = Utils.toEquivalentEmailForm(email2)
    return email1 is email2

  rectVisibleInRect: (r1, r2) ->
    return !(r2.left > r1.right ||  r2.right < r1.left ||  r2.top > r1.bottom || r2.bottom < r1.top)

  isEqualReact: (a, b, options={}) ->
    options.functionsAreEqual = true
    options.ignoreKeys = (options.ignoreKeys ? []).push("clientId")
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
      keys = Object.keys(a)
      length = keys.length
      # Ensure that both objects contain the same number of properties
      # before comparing deep equality.
      if (Object.keys(b).length isnt length) then return false
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

  # Parse json without throwing an error. Logs a sensible message to indicate
  # the error occurred while parsing
  jsonParse: (jsonString) =>
    data = null
    try
      data = JSON.parse(jsonString)
    catch err
      console.error("JSON parse error: #{err}")
    return data

  hueForString: (str='') ->
    str.split('').map((c) -> c.charCodeAt()).reduce((n,a) -> n+a) % 360

  # Emails that nave no-reply or similar phrases in them are likely not a
  # human. As such it's not worth the cost to do a lookup on that person.
  #
  # Also emails that are really long are likely computer-generated email
  # strings used for bcc-based automated teasks.
  likelyNonHumanEmail: (email) ->
    prefixes = [
      "noreply"
      "no-reply"
      "donotreply"
      "do-not-reply"
      "bounce[s]?@"
      "notification[s]?@"
      "support@"
      "alert[s]?@"
      "news@"
      "info@"
      "automated@"
      "list[s]?@"
      "distribute[s]?@"
      "catchall@"
      "catch-all@"
    ]
    reStr = "(#{prefixes.join("|")})"
    re = new RegExp(reStr, "gi")
    return re.test(email) or email.length > 64

  # Does the several tests you need to determine if a test range is within
  # a bounds. Expects both objects to have `start` and `end` keys.
  # Compares any values with <= and >=.
  overlapsBounds: (bounds, test) ->
    # Fully enclosed
    (test.start <= bounds.end and test.end >= bounds.start) or

    # Starts in bounds. Ends out of bounds
    (test.start <= bounds.end and test.start >= bounds.start) or

    # Ends in bounds. Starts out of bounds
    (test.end >= bounds.start and test.end <= bounds.end) or

    # Spans entire boundary
    (test.end >= bounds.end and test.start <= bounds.start)

  mean: (values = []) ->
    if values.length is 0 then throw new Error("Can't average zero values")
    sum = values.reduce(((sum, value) -> sum + value), 0)
    return sum / values.length

  stdev: (values = []) ->
    if values.length is 0 then throw new Error("Can't stdev zero values")
    avg = Utils.mean(values)
    squareDiffs = values.map((val) -> Math.pow((val - avg), 2))
    return Math.sqrt(Utils.mean(squareDiffs))

  # Resolves nested paths in objects of the form "key.subKey.subKey".
  # Null checks along the way.
  #
  # If the result is a function, this will call it with no arguments.
  #
  # Also supports "key1,key2.subkey,key3". The commas lookup those paths
  # in order and takes the first non-blank one.
  #
  # Also supports "key1+key2". This will attempt to concatenate the
  # lookup.
  #
  # Order of operations is "," then "+", then "."
  resolvePath: (fullPath="", model) ->
    commaPaths = fullPath.split(",")
    for commaPath in commaPaths
      joinedVals = []
      paths = commaPath.split("+")
      for path in paths
        parts = path.split(".")
        curVal = model
        for part in parts
          if _.isFunction(curVal[part])
            curVal = curVal[part]()
          else
            curVal = curVal[part]
          if not curVal or curVal.length is 0
            curVal = null
            break
        joinedVals.push(curVal)
      joinedVals = _.compact(joinedVals)
      continue if joinedVals.length is 0
      return joinedVals.join(" ")
    return null
