_ = require 'underscore-plus'
fs = require('fs-plus')
path = require('path')

tz = Intl.DateTimeFormat().resolvedOptions().timeZone

module.exports =
Utils =
  timeZone: tz

  modelClassMap: ->
    Thread = require './thread'
    Message = require './message'
    Namespace = require './namespace'
    Tag = require './tag'
    File = require './file'
    Contact = require './contact'
    LocalLink = require './local-link'
    Event = require './event'
    Calendar = require './calendar'

    ## TODO move to inside of individual Salesforce package. See https://trello.com/c/tLAGLyeb/246-move-salesforce-models-into-individual-package-db-models-for-packages-various-refactors
    SalesforceAssociation = require './salesforce-association'
    SalesforceContact = require './salesforce-contact'
    SalesforceTask = require './salesforce-task'

    SyncbackDraftTask = require '../tasks/syncback-draft'
    SendDraftTask = require '../tasks/send-draft'
    DestroyDraftTask = require '../tasks/destroy-draft'
    AddRemoveTagsTask = require '../tasks/add-remove-tags'
    MarkThreadReadTask = require '../tasks/mark-thread-read'
    MarkMessageReadTask = require '../tasks/mark-message-read'
    FileUploadTask = require '../tasks/file-upload-task'

    return {
      'thread': Thread
      'message': Message
      'draft': Message
      'contact': Contact
      'namespace': Namespace
      'file': File
      'tag': Tag
      'locallink': LocalLink
      'calendar': Calendar
      'event': Event
      'salesforceassociation': SalesforceAssociation
      'salesforcecontact': SalesforceContact
      'SalesforceTask': SalesforceTask

      'MarkThreadReadTask': MarkThreadReadTask
      'MarkMessageReadTask': MarkMessageReadTask
      'AddRemoveTagsTask': AddRemoveTagsTask
      'SendDraftTask': SendDraftTask
      'SyncbackDraftTask': SyncbackDraftTask
      'DestroyDraftTask': DestroyDraftTask
      'FileUploadTask': FileUploadTask
    }

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
      if !o.hasOwnProperty(key) || typeof prop isnt 'object' || Object.isFrozen(prop)
        continue
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
  
  imageNamed: (fullname) ->
    [name, ext] = fullname.split('.')

    if Utils.images is undefined
      start = Date.now()
      {resourcePath} = atom.getLoadSettings()
      imagesPath = path.join(resourcePath, 'static', 'images')
      files = fs.listTreeSync(imagesPath)

      Utils.images = {}
      Utils.images[path.basename(file)] = file for file in files

    if window.devicePixelRatio > 1
      return Utils.images["#{name}@2x.#{ext}"] ? Utils.images[fullname] ? Utils.images["#{name}@1x.#{ext}"]
    else
      return Utils.images["#{name}@1x.#{ext}"] ? Utils.images[fullname] ? Utils.images["#{name}@2x.#{ext}"]

  subjectWithPrefix: (subject, prefix) ->
    if subject.search(/fwd:/i) is 0
      return subject.replace(/fwd:/i, prefix)
    else if subject.search(/re:/i) is 0
      return subject.replace(/re:/i, prefix)
    else
      return "#{prefix} #{subject}"

  # A wrapper around String#search(). Returns the index of the first match
  # or returns -1 if there are no matches
  quotedTextIndex: (html) ->
    # I know this is gross - one day we'll replace it with a nice system.
    return -1 unless html

    regexs = [
      /<blockquote/i, # blockquote element
      /\n[ ]*(>|&gt;)/, # Plaintext lines beginning with >
      /<[br|p][ ]*>[\n]?[ ]*&gt;/i, # HTML lines beginning with >
      /[\n|>]On .* wrote:[\n|<]/, #On ... wrote: on it's own line
      /.gmail_quote/ # gmail quote class class
    ]

    for regex in regexs
      foundIndex = html.search(regex)
      if foundIndex >= 0 then return foundIndex

    return -1

  stripQuotedText: (html) ->
    return html if Utils.quotedTextIndex(html) is -1

    # Split the email into lines and remove lines that begin with > or &gt;
    lines = html.split(/(\n|<br[^>]*>)/)

    # Remove lines that are newlines - we'll add them back in when we join.
    # We had to break them out because we want to preserve <br> elements.
    lines = _.reject lines, (line) -> line == '\n'

    regexs = [
      /\n[ ]*(>|&gt;)/, # Plaintext lines beginning with >
      /<[br|p][ ]*>[\n]?[ ]*[>|&gt;]/i, # HTML lines beginning with >
      /[\n|>]On .* wrote:[\n|<]/, #On ... wrote: on it's own line
    ]
    for ii in [lines.length-1..0] by -1
      continue if not lines[ii]?
      for regex in regexs
        # Never remove a line with a blockquote start tag, because it
        # quotes multiple lines, not just the current line!
        if lines[ii].match("<blockquote")
          break
        if lines[ii].match(regex)
          lines.splice(ii,1)
          # Remove following line if its just a spacer-style element
          lines.splice(ii,1) if lines[ii]?.match('<br[^>]*>')?[0] is lines[ii]
          break

    # Return remaining compacted email body
    lines.join('\n')

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

  # Checks to see if a particular node is visible and any of its parents
  # are visible.
  #
  # WARNING. This is a fairly expensive operation and should be used
  # sparingly.
  nodeIsVisible: (node) ->
    while node
      style = window.getComputedStyle(node)
      node = node.parentNode
      continue unless style?
      # NOTE: opacity must be soft ==
      if style.opacity is 0 or style.opacity is "0" or style.visibility is "hidden" or style.display is "none"
        return false
    return true

  # True of all arguments have the same domains
  emailsHaveSameDomain: (args...) ->
    return false if args.length < 2
    domains = args.map (email="") ->
      _.last(email.toLowerCase().trim().split("@"))
    toMatch = domains[0]
    return _.every(domains, (domain) -> domain.length > 0 and toMatch is domain)

  emailRegex: /[a-z.A-Z0-9%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}/g

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
    if (a._wrapped?) then a = a._wrapped
    if (b._wrapped?) then b = b._wrapped

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
