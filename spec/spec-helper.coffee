_ = require 'underscore'
_str = require 'underscore.string'
fs = require 'fs-plus'
path = require 'path'

require '../src/window'
NylasEnv.restoreWindowDimensions()

require 'jasmine-json'
require './jasmine-jquery'

Grim = require 'grim'
TimeOverride = require './time-override'
KeymapManager = require '../src/keymap-manager'

# FIXME: Remove jquery from this
{$} = require '../src/space-pen-extensions'

Config = require '../src/config'
ServiceHub = require 'service-hub'
pathwatcher = require 'pathwatcher'
{clipboard} = require 'electron'

{Account,
 Contact,
 TaskQueue,
 AccountStore,
 DatabaseStore,
 MailboxPerspective,
 FocusedPerspectiveStore,
 ComponentRegistry} = require "nylas-exports"

NylasEnv.themes.loadBaseStylesheets()
NylasEnv.themes.requireStylesheet '../static/jasmine'
NylasEnv.themes.initialLoadComplete = true

NylasEnv.keymaps.loadBundledKeymaps()
keyBindingsToRestore = NylasEnv.keymaps.getKeyBindings()
commandsToRestore = NylasEnv.commands.getSnapshot()
styleElementsToRestore = NylasEnv.styles.getSnapshot()

window.addEventListener 'core:close', -> window.close()
window.addEventListener 'beforeunload', ->
  NylasEnv.storeWindowDimensions()
  NylasEnv.saveSync()
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
  jasmine.getEnv().defaultTimeoutInterval = 250

specPackageName = null
specPackagePath = null
isCoreSpec = false

{specDirectory, resourcePath} = NylasEnv.getLoadSettings()

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

# So it passes the Utils.isTempId test
window.TEST_ACCOUNT_CLIENT_ID = "local-test-account-client-id"
window.TEST_ACCOUNT_ID = "test-account-server-id"
window.TEST_ACCOUNT_EMAIL = "tester@nylas.com"
window.TEST_ACCOUNT_NAME = "Nylas Test"
window.TEST_PLUGIN_ID = "test-plugin-id-123"

beforeEach ->
  NylasEnv.testOrganizationUnit = null
  Grim.clearDeprecations() if isCoreSpec
  ComponentRegistry._clear()
  global.localStorage.clear()

  DatabaseStore._transactionQueue = undefined

  ## If we don't spy on DatabaseStore._query, then
  #`DatabaseStore.inTransaction` will never complete and cause all tests
  #that depend on transactions to hang.
  #
  # @_query("BEGIN IMMEDIATE TRANSACTION") never resolves because
  # DatabaseStore._query never runs because the @_open flag is always
  # false because we never setup the DB when `NylasEnv.inSpecMode` is
  # true.
  spyOn(DatabaseStore, '_query').andCallFake => Promise.resolve([])

  TaskQueue._queue = []
  TaskQueue._completed = []
  TaskQueue._onlineStatus = true

  $.fx.off = true
  documentTitle = null
  NylasEnv.packages.serviceHub = new ServiceHub
  NylasEnv.keymaps.keyBindings = _.clone(keyBindingsToRestore)
  NylasEnv.commands.restoreSnapshot(commandsToRestore)
  NylasEnv.styles.restoreSnapshot(styleElementsToRestore)
  NylasEnv.workspaceViewParentSelector = '#jasmine-content'

  NylasEnv.packages.packageStates = {}

  serializedWindowState = null

  spyOn(NylasEnv, 'saveSync')

  TimeOverride.resetTime()
  TimeOverride.enableSpies()

  spy = spyOn(NylasEnv.packages, 'resolvePackagePath').andCallFake (packageName) ->
    if specPackageName and packageName is specPackageName
      resolvePackagePath(specPackagePath)
    else
      resolvePackagePath(packageName)
  resolvePackagePath = _.bind(spy.originalValue, NylasEnv.packages)

  # prevent specs from modifying N1's menus
  spyOn(NylasEnv.menu, 'sendToBrowserProcess')

  # Log in a fake user, and ensure that accountForId, etc. work
  AccountStore._index = 0
  AccountStore._accounts = [
    new Account({
      provider: "gmail"
      name: TEST_ACCOUNT_NAME
      emailAddress: TEST_ACCOUNT_EMAIL
      organizationUnit: NylasEnv.testOrganizationUnit || 'label'
      clientId: TEST_ACCOUNT_CLIENT_ID
      serverId: TEST_ACCOUNT_ID
    })
  ]

  FocusedPerspectiveStore._current = MailboxPerspective.forNothing()

  # reset config before each spec; don't load or save from/to `config.json`
  spyOn(Config::, 'load')
  spyOn(Config::, 'save')
  config = new Config({resourcePath, configDirPath: NylasEnv.getConfigDirPath()})
  NylasEnv.config = config
  NylasEnv.loadConfig()
  config.set "core.destroyEmptyPanes", false
  config.set "editor.fontFamily", "Courier"
  config.set "editor.fontSize", 16
  config.set "editor.autoIndent", false
  config.set "core.disabledPackages", ["package-that-throws-an-exception",
    "package-with-broken-package-json", "package-with-broken-keymap"]
  config.set "editor.useShadowDOM", true
  advanceClock(1000)
  config.load.reset()
  config.save.reset()

  spyOn(pathwatcher.File.prototype, "detectResurrectionAfterDelay").andCallFake -> @detectResurrection()

  clipboardContent = 'initial clipboard content'
  spyOn(clipboard, 'writeText').andCallFake (text) -> clipboardContent = text
  spyOn(clipboard, 'readText').andCallFake -> clipboardContent

  addCustomMatchers(this)

  TimeOverride.resetSpyData()

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

  NylasEnv.packages.deactivatePackages()
  NylasEnv.menu.template = []

  NylasEnv.themes.removeStylesheet('global-editor-styles')

  delete NylasEnv.state?.packageStates

  $('#jasmine-content').empty() unless window.debugContent

  ReactTestUtils.unmountAll()

  jasmine.unspy(NylasEnv, 'saveSync')
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
    # the app still use other Promise libraries Just see if it looks
    # promise-like.
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

window.pagePixelPositionForPoint = (editorView, point) ->
  point = Point.fromObject point
  top = editorView.renderedLines.offset().top + point.row * editorView.lineHeight
  left = editorView.renderedLines.offset().left + point.column * editorView.charWidth - editorView.renderedLines.scrollLeft()
  { top, left }
