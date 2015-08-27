require '../src/window'
atom.initialize()
atom.restoreWindowDimensions()

require 'jasmine-json'
require '../vendor/jasmine-jquery'
path = require 'path'
_ = require 'underscore'
_str = require 'underscore.string'
fs = require 'fs-plus'
Grim = require 'grim'
KeymapManager = require '../src/keymap-extensions'

# FIXME: Remove jquery from this
{$} = require '../src/space-pen-extensions'

Config = require '../src/config'
ServiceHub = require 'service-hub'
pathwatcher = require 'pathwatcher'
clipboard = require 'clipboard'

AccountStore = require "../src/flux/stores/account-store"
Contact = require '../src/flux/models/contact'
{TaskQueue, ComponentRegistry} = require "nylas-exports"

atom.themes.loadBaseStylesheets()
atom.themes.requireStylesheet '../static/jasmine'
atom.themes.initialLoadComplete = true

atom.keymaps.loadBundledKeymaps()
keyBindingsToRestore = atom.keymaps.getKeyBindings()
commandsToRestore = atom.commands.getSnapshot()
styleElementsToRestore = atom.styles.getSnapshot()

window.addEventListener 'core:close', -> window.close()
window.addEventListener 'beforeunload', ->
  atom.storeWindowDimensions()
  atom.saveSync()
$('html,body').css('overflow', 'auto')

# Allow document.title to be assigned in specs without screwing up spec window title
documentTitle = null
Object.defineProperty document, 'title',
  get: -> documentTitle
  set: (title) -> documentTitle = title

jasmine.getEnv().addEqualityTester(_.isEqual) # Use underscore's definition of equality for toEqual assertions

if process.env.JANKY_SHA1 and process.platform is 'win32'
  jasmine.getEnv().defaultTimeoutInterval = 60000
else
  jasmine.getEnv().defaultTimeoutInterval = 500

specPackageName = null
specPackagePath = null
isCoreSpec = false

{specDirectory, resourcePath} = atom.getLoadSettings()

if specDirectory
  specPackagePath = path.resolve(specDirectory, '..')
  try
    specPackageName = JSON.parse(fs.readFileSync(path.join(specPackagePath, 'package.json')))?.name

isCoreSpec = specDirectory == fs.realpathSync(__dirname)

# Override React.addons.TestUtils.renderIntoDocument so that
# we can remove all the created elements after the test completes.
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
ReactTestUtils.scryRenderedComponentsWithTypeAndProps = (root, type, props) ->
  if not root then throw new Error("Must supply a root to scryRenderedComponentsWithTypeAndProps")
  _.compact _.map ReactTestUtils.scryRenderedComponentsWithType(root, type), (el) ->
    if _.isEqual(_.pick(el.props, Object.keys(props)), props)
      return el
    else
      return false

ReactTestUtils.scryRenderedDOMComponentsWithAttr = (root, attrName, attrValue) ->
  ReactTestUtils.findAllInRenderedTree root, (inst) ->
    inst.props[attrName] and (!attrValue or inst.props[attrName] is attrValue)

ReactTestUtils.findRenderedDOMComponentWithAttr = (root, attrName, attrValue) ->
  all = ReactTestUtils.scryRenderedDOMComponentsWithAttr(root, attrName, attrValue)
  if all.length is not 1
    throw new Error("Did not find exactly one match for data attribute: #{attrName} with value: #{attrValue}")
  all[0]

ReactElementContainers = []
ReactTestUtils.renderIntoDocument = (element) ->
  container = document.createElement('div')
  ReactElementContainers.push(container)
  React.render(element, container)

ReactTestUtils.unmountAll = ->
  for container in ReactElementContainers
    React.unmountComponentAtNode(container)
  ReactElementContainers = []

# Make Bluebird use setTimeout so that it hooks into our stubs, and you can
# advance promises using `advanceClock()`. To avoid breaking any specs that
# `dont` manually call advanceClock, call it automatically on the next tick.
Promise.setScheduler (fn) ->
  setTimeout(fn, 0)
  process.nextTick -> advanceClock(1)

beforeEach ->
  atom.testOrganizationUnit = null
  Grim.clearDeprecations() if isCoreSpec
  ComponentRegistry._clear()
  global.localStorage.clear()

  TaskQueue._queue = []
  TaskQueue._completed = []
  TaskQueue._onlineStatus = true

  $.fx.off = true
  documentTitle = null
  atom.packages.serviceHub = new ServiceHub
  atom.keymaps.keyBindings = _.clone(keyBindingsToRestore)
  atom.commands.restoreSnapshot(commandsToRestore)
  atom.styles.restoreSnapshot(styleElementsToRestore)
  atom.workspaceViewParentSelector = '#jasmine-content'

  window.resetTimeouts()
  spyOn(_._, "now").andCallFake -> window.now
  spyOn(window, "setTimeout").andCallFake window.fakeSetTimeout
  spyOn(window, "clearTimeout").andCallFake window.fakeClearTimeout
  spyOn(window, "setInterval").andCallFake window.fakeSetInterval
  spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

  atom.packages.packageStates = {}

  serializedWindowState = null

  spyOn(atom, 'saveSync')

  spy = spyOn(atom.packages, 'resolvePackagePath').andCallFake (packageName) ->
    if specPackageName and packageName is specPackageName
      resolvePackagePath(specPackagePath)
    else
      resolvePackagePath(packageName)
  resolvePackagePath = _.bind(spy.originalValue, atom.packages)

  # prevent specs from modifying Atom's menus
  spyOn(atom.menu, 'sendToBrowserProcess')

  # Log in a fake user
  spyOn(AccountStore, 'current').andCallFake ->
    emailAddress: 'tester@nylas.com'
    id: 'test_account_id'
    usesLabels: -> atom.testOrganizationUnit is "label"
    usesFolders: -> atom.testOrganizationUnit is "folder"
    me: ->
      new Contact(email: 'tester@nylas.com', name: 'Ben Tester')

  # reset config before each spec; don't load or save from/to `config.json`
  spyOn(Config::, 'load')
  spyOn(Config::, 'save')
  config = new Config({resourcePath, configDirPath: atom.getConfigDirPath()})
  atom.config = config
  atom.loadConfig()
  config.set "core.destroyEmptyPanes", false
  config.set "editor.fontFamily", "Courier"
  config.set "editor.fontSize", 16
  config.set "editor.autoIndent", false
  config.set "core.disabledPackages", ["package-that-throws-an-exception",
    "package-with-broken-package-json", "package-with-broken-keymap"]
  config.set "editor.useShadowDOM", true
  advanceClock(1000)
  window.setTimeout.reset()
  config.load.reset()
  config.save.reset()

  spyOn(pathwatcher.File.prototype, "detectResurrectionAfterDelay").andCallFake -> @detectResurrection()

  clipboardContent = 'initial clipboard content'
  spyOn(clipboard, 'writeText').andCallFake (text) -> clipboardContent = text
  spyOn(clipboard, 'readText').andCallFake -> clipboardContent

  addCustomMatchers(this)


original_log = console.log
original_warn = console.warn
original_error = console.error

afterEach ->

  if console.log isnt original_log
    console.log = original_log
  if console.warn isnt original_warn
    console.warn = original_warn
  if console.error isnt original_error
    console.error = original_error

  atom.packages.deactivatePackages()
  atom.menu.template = []

  atom.themes.removeStylesheet('global-editor-styles')

  delete atom.state?.packageStates

  $('#jasmine-content').empty() unless window.debugContent

  ReactTestUtils.unmountAll()

  jasmine.unspy(atom, 'saveSync')
  ensureNoPathSubscriptions()
  waits(0) # yield to ui thread to make screen update more frequently

ensureNoPathSubscriptions = ->
  watchedPaths = pathwatcher.getWatchedPaths()
  pathwatcher.closeAllWatchers()
  if watchedPaths.length > 0
    throw new Error("Leaking subscriptions for paths: " + watchedPaths.join(", "))

ensureNoDeprecatedFunctionsCalled = ->
  deprecations = Grim.getDeprecations()
  if deprecations.length > 0
    originalPrepareStackTrace = Error.prepareStackTrace
    Error.prepareStackTrace = (error, stack) ->
      output = []
      for deprecation in deprecations
        output.push "#{deprecation.originName} is deprecated. #{deprecation.message}"
        output.push _str.repeat("-", output[output.length - 1].length)
        for stack in deprecation.getStacks()
          for {functionName, location} in stack
            output.push "#{functionName} -- #{location}"
        output.push ""
      output.join("\n")

    error = new Error("Deprecated function(s) #{deprecations.map(({originName}) -> originName).join ', '}) were called.")
    error.stack
    Error.prepareStackTrace = originalPrepareStackTrace

    throw error

emitObject = jasmine.StringPrettyPrinter.prototype.emitObject
jasmine.StringPrettyPrinter.prototype.emitObject = (obj) ->
  if obj.inspect
    @append obj.inspect()
  else
    emitObject.call(this, obj)

jasmine.unspy = (object, methodName) ->
  throw new Error("Not a spy") unless object[methodName].hasOwnProperty('originalValue')
  object[methodName] = object[methodName].originalValue

jasmine.attachToDOM = (element) ->
  jasmineContent = document.querySelector('#jasmine-content')
  jasmineContent.appendChild(element) unless jasmineContent.contains(element)

deprecationsSnapshot = null
jasmine.snapshotDeprecations = ->
  deprecationsSnapshot = _.clone(Grim.deprecations)

jasmine.restoreDeprecationsSnapshot = ->
  Grim.deprecations = deprecationsSnapshot

jasmine.useRealClock = ->
  jasmine.unspy(window, 'setTimeout')
  jasmine.unspy(window, 'clearTimeout')
  jasmine.unspy(window, 'setInterval')
  jasmine.unspy(window, 'clearInterval')
  jasmine.unspy(_._, 'now')

addCustomMatchers = (spec) ->
  spec.addMatchers
    toBeInstanceOf: (expected) ->
      notText = if @isNot then " not" else ""
      this.message = => "Expected #{jasmine.pp(@actual)} to#{notText} be instance of #{expected.name} class"
      @actual instanceof expected

    toHaveLength: (expected) ->
      if not @actual?
        this.message = => "Expected object #{@actual} has no length method"
        false
      else
        notText = if @isNot then " not" else ""
        this.message = => "Expected object with length #{@actual.length} to#{notText} have length #{expected}"
        @actual.length == expected

    toExistOnDisk: (expected) ->
      notText = this.isNot and " not" or ""
      @message = -> return "Expected path '" + @actual + "'" + notText + " to exist."
      fs.existsSync(@actual)

    toHaveFocus: ->
      notText = this.isNot and " not" or ""
      if not document.hasFocus()
        console.error "Specs will fail because the Dev Tools have focus. To fix this close the Dev Tools or click the spec runner."

      @message = -> return "Expected element '" + @actual + "' or its descendants" + notText + " to have focus."
      element = @actual
      element = element.get(0) if element.jquery
      element is document.activeElement or element.contains(document.activeElement)

    toShow: ->
      notText = if @isNot then " not" else ""
      element = @actual
      element = element.get(0) if element.jquery
      @message = -> return "Expected element '#{element}' or its descendants#{notText} to show."
      element.style.display in ['block', 'inline-block', 'static', 'fixed']

window.keyIdentifierForKey = (key) ->
  if key.length > 1 # named key
    key
  else
    charCode = key.toUpperCase().charCodeAt(0)
    "U+00" + charCode.toString(16)

window.keydownEvent = (key, properties={}) ->
  originalEventProperties = {}
  originalEventProperties.ctrl = properties.ctrlKey
  originalEventProperties.alt = properties.altKey
  originalEventProperties.shift = properties.shiftKey
  originalEventProperties.cmd = properties.metaKey
  originalEventProperties.target = properties.target?[0] ? properties.target
  originalEventProperties.which = properties.which
  originalEvent = KeymapManager.keydownEvent(key, originalEventProperties)
  properties = $.extend({originalEvent}, properties)
  $.Event("keydown", properties)

window.mouseEvent = (type, properties) ->
  if properties.point
    {point, editorView} = properties
    {top, left} = @pagePixelPositionForPoint(editorView, point)
    properties.pageX = left + 1
    properties.pageY = top + 1
  properties.originalEvent ?= {detail: 1}
  $.Event type, properties

window.clickEvent = (properties={}) ->
  window.mouseEvent("click", properties)

window.mousedownEvent = (properties={}) ->
  window.mouseEvent('mousedown', properties)

window.mousemoveEvent = (properties={}) ->
  window.mouseEvent('mousemove', properties)

# See docs/writing-specs.md
window.waitsForPromise = (args...) ->
  if args.length > 1
    { shouldReject, timeout } = args[0]
  else
    shouldReject = false
  fn = _.last(args)

  window.waitsFor timeout, (moveOn) ->
    promise = fn()
    # Keep in mind we can't check `promise instanceof Promise` because parts of
    # the app still use other Promise libraries (Atom used Q, we use Bluebird.)
    # Just see if it looks promise-like.
    if not promise or not promise.then
      jasmine.getEnv().currentSpec.fail("Expected callback to return a promise-like object, but it returned #{promise}")
      moveOn()
    else if shouldReject
      promise.catch(moveOn)
      promise.then ->
        jasmine.getEnv().currentSpec.fail("Expected promise to be rejected, but it was resolved")
        moveOn()
    else
      promise.then(moveOn)
      promise.catch (error) ->
        # I don't know what `pp` does, but for standard `new Error` objects,
        # it sometimes returns "{  }". Catch this case and fall through to toString()
        msg = jasmine.pp(error)
        msg = error.toString() if msg is "{  }"
        jasmine.getEnv().currentSpec.fail("Expected promise to be resolved, but it was rejected with #{msg}")
        moveOn()

window.resetTimeouts = ->
  window.now = 0
  window.timeoutCount = 0
  window.intervalCount = 0
  window.timeouts = []
  window.intervalTimeouts = {}

window.fakeSetTimeout = (callback, ms) ->
  id = ++window.timeoutCount
  window.timeouts.push([id, window.now + ms, callback])
  id

window.fakeClearTimeout = (idToClear) ->
  window.timeouts ?= []
  window.timeouts = window.timeouts.filter ([id]) -> id != idToClear

window.fakeSetInterval = (callback, ms) ->
  id = ++window.intervalCount
  action = ->
    callback()
    window.intervalTimeouts[id] = window.fakeSetTimeout(action, ms)
  window.intervalTimeouts[id] = window.fakeSetTimeout(action, ms)
  id

window.fakeClearInterval = (idToClear) ->
  window.fakeClearTimeout(@intervalTimeouts[idToClear])

window.advanceClock = (delta=1) ->
  window.now += delta
  callbacks = []

  window.timeouts ?= []
  window.timeouts = window.timeouts.filter ([id, strikeTime, callback]) ->
    if strikeTime <= window.now
      callbacks.push(callback)
      false
    else
      true

  callback() for callback in callbacks

window.pagePixelPositionForPoint = (editorView, point) ->
  point = Point.fromObject point
  top = editorView.renderedLines.offset().top + point.row * editorView.lineHeight
  left = editorView.renderedLines.offset().left + point.column * editorView.charWidth - editorView.renderedLines.scrollLeft()
  { top, left }

window.tokensText = (tokens) ->
  _.pluck(tokens, 'value').join('')

window.setEditorWidthInChars = (editorView, widthInChars, charWidth=editorView.charWidth) ->
  editorView.width(charWidth * widthInChars + editorView.gutter.outerWidth())
  $(window).trigger 'resize' # update width of editor view's on-screen lines

window.setEditorHeightInLines = (editorView, heightInLines, lineHeight=editorView.lineHeight) ->
  editorView.height(editorView.getEditor().getLineHeightInPixels() * heightInLines)
  editorView.component?.measureHeightAndWidth()

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result

$.fn.enableKeymap = ->
  @on 'keydown', (e) ->
    originalEvent = e.originalEvent ? e
    Object.defineProperty(originalEvent, 'target', get: -> e.target) unless originalEvent.target?
    atom.keymaps.handleKeyboardEvent(originalEvent)
    not e.originalEvent.defaultPrevented

$.fn.attachToDom = ->
  @appendTo($('#jasmine-content')) unless @isOnDom()

$.fn.simulateDomAttachment = ->
  $('<html>').append(this)

$.fn.textInput = (data) ->
  this.each ->
    event = document.createEvent('TextEvent')
    event.initTextEvent('textInput', true, true, window, data)
    event = $.event.fix(event)
    $(this).trigger(event)
