_ = require 'underscore'
React = require 'react'

{Utils, DOMUtils} = require 'nylas-exports'
{KeyCommandsRegion} = require 'nylas-component-kit'
FloatingToolbar = require './floating-toolbar'

EditorAPI = require './editor-api'
ExtendedSelection = require './extended-selection'

TabManager = require './tab-manager'
LinkManager = require './link-manager'
ListManager = require './list-manager'
MouseService = require './mouse-service'
DOMNormalizer = require './dom-normalizer'
ClipboardService = require './clipboard-service'
BlockquoteManager = require './blockquote-manager'
ToolbarButtonManager = require './toolbar-button-manager'
EmphasisFormattingExtension = require './emphasis-formatting-extension'
ParagraphFormattingExtension = require './paragraph-formatting-extension'

###
Public: A modern React-compatible contenteditable

This <Contenteditable /> component is fully React-compatible and behaves
like a standard controlled input.

```javascript
getInitialState: function() {
  return {value: '<strong>Hello!</strong>'};
},
handleChange: function(event) {
  this.setState({value: event.target.value});
},
render: function() {
  var value = this.state.value;
  return <Contenteditable type="text" value={value} onChange={this.handleChange} />;
}
```
###
class Contenteditable extends React.Component
  @displayName: "Contenteditable"

  @propTypes:
    # The current html state, as a string, of the contenteditable.
    value: React.PropTypes.string

    # Initial content selection that was previously saved
    initialSelectionSnapshot: React.PropTypes.object,

    # Handlers
    onChange: React.PropTypes.func.isRequired
    onFilePaste: React.PropTypes.func

    # A list of objects that extend {ContenteditableExtension}
    extensions: React.PropTypes.array

    spellcheck: React.PropTypes.bool

    floatingToolbar: React.PropTypes.bool

  @defaultProps:
    extensions: []
    spellcheck: true
    floatingToolbar: true
    onSelectionChanged: =>

  coreServices: [MouseService, ClipboardService]

  coreExtensions: [
    ToolbarButtonManager
    ListManager
    TabManager
    EmphasisFormattingExtension
    ParagraphFormattingExtension
    LinkManager
    BlockquoteManager
    DOMNormalizer
  ]

  ######################################################################
  ########################### Public Methods ###########################
  ######################################################################

  ### Public: perform an editing operation on the Contenteditable

  - `editingFunction` A function to mutate the DOM and
  {ExtendedSelection}. It gets passed an {EditorAPI} object that contains
  mutating methods.

  If the current selection at the time of running the extension is out of
  scope, it will be set to the last saved state. This ensures extensions
  operate on a valid {ExtendedSelection}.

  Edits made within the editing function will eventually fire _onDOMMutated
  ###
  atomicEdit: (editingFunction, extraArgsObj={}) =>
    @_teardownNonMutationListeners()

    editor = new EditorAPI(@_editableNode())

    if not editor.currentSelection().isInScope()
      @_restoreSelection()

    argsObj = _.extend(extraArgsObj, {editor})

    try
      editingFunction(argsObj)
    catch error
      NylasEnv.reportError(error)

    @_setupNonMutationListeners()

  focus: => @_editableNode().focus()


  ######################################################################
  ########################## React Lifecycle ###########################
  ######################################################################

  constructor: (@props) ->
    @state = {}
    @innerState = {
      dragging: false
      doubleDown: false
      hoveringOver: false # see {MouseService}
      editableNode: null
      exportedSelection: null
      previousExportedSelection: null
    }
    @_mutationObserver = new MutationObserver(@_onDOMMutated)

  componentWillMount: =>
    @_setupServices()

  componentDidMount: =>
    @setInnerState editableNode: @_editableNode()
    @_setupNonMutationListeners()
    @_mutationObserver.observe(@_editableNode(), @_mutationConfig())

  # When we have a composition event in progress, we should not update
  # because otherwise our composition event will be blown away.
  shouldComponentUpdate: (nextProps, nextState) ->
    not @_inCompositionEvent and
    (not Utils.isEqualReact(nextProps, @props) or
     not Utils.isEqualReact(nextState, @state))

  componentWillReceiveProps: (nextProps) =>
    if nextProps.initialSelectionSnapshot?
      @setInnerState
        exportedSelection: nextProps.initialSelectionSnapshot
        previousExportedSelection: @innerState.exportedSelection

  componentDidUpdate: =>
    @_restoreSelection() if @_shouldRestoreSelectionOnUpdate()
    @_refreshServices()
    @_mutationObserver.disconnect()
    @_mutationObserver.observe(@_editableNode(), @_mutationConfig())
    @setInnerState editableNode: @_editableNode()

  componentWillUnmount: =>
    @_mutationObserver.disconnect()
    @_teardownNonMutationListeners()
    @_teardownServices()

  setInnerState: (innerState={}) =>
    return if _.isMatch(@innerState, innerState)
    @innerState = _.extend @innerState, innerState
    if @_broadcastInnerStateToToolbar
      @refs["toolbarController"]?.componentWillReceiveInnerProps(@innerState)
    @_refreshServices()

  _setupServices: ->
    @_services = @coreServices.map (Service) =>
      new Service
        data: {@props, @state, @innerState}
        methods: {@setInnerState, @dispatchEventToExtensions}

  _refreshServices: ->
    service.setData({@props, @state, @innerState}) for service in @_services

  _teardownServices: ->
    service.teardown() for service in @_services


  ######################################################################
  ############################## Render ################################
  ######################################################################

  render: =>
    <KeyCommandsRegion className="contenteditable-container"
                       localHandlers={@_keymapHandlers()}>
      {@_renderFloatingToolbar()}

      <div className="contenteditable no-open-link-events"
           ref="contenteditable"
           contentEditable
           spellCheck={false}
           dangerouslySetInnerHTML={__html: @props.value}
           {...@_eventHandlers()}></div>
    </KeyCommandsRegion>

  _renderFloatingToolbar: ->
    return unless @props.floatingToolbar
    <FloatingToolbar
        ref="toolbarController"
        atomicEdit={@atomicEdit}
        extensions={@_extensions()} />

  _editableNode: =>
    React.findDOMNode(@refs.contenteditable)


  ######################################################################
  ########################### Listener Setup ###########################
  ######################################################################

  _eventHandlers: =>
    handlers = {}
    _.extend(handlers, service.eventHandlers()) for service in @_services

    # NOTE: See {MouseService} for more handlers
    handlers = _.extend handlers,
      onBlur: @_onBlur
      onFocus: @_onFocus
      onKeyDown: @_onKeyDown
      onCompositionEnd: @_onCompositionEnd
      onCompositionStart: @_onCompositionStart
    return handlers

  # This extracts extensions keymap handlers and binds them to be called
  # through `atomicEdit`. This exposes the `{editor, event}` props to any
  # keyCommandHandlers callbacks.
  _boundExtensionKeymapHandlers: ->
    keymapHandlers = {}
    @_extensions().forEach (extension) =>
      return unless _.isFunction(extension.keyCommandHandlers)
      try
        extensionHandlers = extension.keyCommandHandlers.call(extension)
        _.each extensionHandlers, (handler, command) =>
          keymapHandlers[command] = (event) =>
            @atomicEdit(handler, {event})
      catch error
        NylasEnv.reportError(error)
    return keymapHandlers

  # NOTE: Keymaps are now broken apart into individual extensions. See the
  # `EmphasisFormattingExtension`, `ParagraphFormattingExtension`,
  # `ListManager`, and `LinkManager` for examples of extensions listening
  # to keymaps.
  _keymapHandlers: ->
    defaultKeymaps = {}
    return _.extend(defaultKeymaps, @_boundExtensionKeymapHandlers())

  _setupNonMutationListeners: =>
    @_broadcastInnerStateToToolbar = true
    document.addEventListener("selectionchange", @_saveSelection)
    @_editableNode().addEventListener('contextmenu', @_onShowContextMenu)

  _teardownNonMutationListeners: =>
    @_broadcastInnerStateToToolbar = false
    document.removeEventListener("selectionchange", @_saveSelection)
    @_editableNode().removeEventListener('contextmenu', @_onShowContextMenu)

  # https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver
  _mutationConfig: ->
    subtree: true
    childList: true
    attributes: true
    characterData: true
    attributeOldValue: true
    characterDataOldValue: true


  ######################################################################
  ########################### Event Handlers ###########################
  ######################################################################

  # Every time the contents of the contenteditable DOM node change, the
  # `_onDOMMutated` event gets fired.
  #
  # If we are in the middle of an `atomic` change transaction, we ignore
  # those changes.
  #
  # At all other times we take the change, apply various filters to the
  # new content, then notify our parent that the content has been updated.
  _onDOMMutated: (mutations) =>
    return unless mutations and mutations.length > 0

    @_mutationObserver.disconnect()
    @setInnerState dragging: false if @innerState.dragging
    @setInnerState doubleDown: false if @innerState.doubleDown
    @_broadcastInnerStateToToolbar = false

    @_runCallbackOnExtensions("onContentChanged", {mutations})

    # NOTE: The DOMNormalizer should be the last extension to run. This
    # will ensure that when we extract our innerHTML and re-set it during
    # the next render the contents should look identical.
    #
    # Also, remember that our selection listeners have been turned off.
    # It's very likely that one of our callbacks mutated the DOM and the
    # selection. We need to be sure to re-save the selection.
    @_saveSelection()

    @props.onChange(target: {value: @_editableNode().innerHTML})

    @_broadcastInnerStateToToolbar = true
    @_mutationObserver.observe(@_editableNode(), @_mutationConfig())
    return

  _onBlur: (event) =>
    @setInnerState dragging: false
    return if @_editableNode().parentElement.contains event.relatedTarget
    @dispatchEventToExtensions("onBlur", event)

  _onFocus: (event) =>
    @dispatchEventToExtensions("onFocus", event)

  _onKeyDown: (event) =>
    @dispatchEventToExtensions("onKeyDown", event)

  # We must set the `inCompositionEvent` flag in addition to tearing down
  # the selecton listeners. While the composition event is in progress, we
  # want to ignore any input events we get.
  #
  # It is also possible for a composition event to end and then
  # immediately start a new composition event. This happens when two
  # composition event-triggering characters are pressed twice in a row.
  # When the first composition event ends, the `_onDOMMutated` method fires (as
  # it's supposed to) and sends off an asynchronous update request when we
  # `_saveNewHtml`. Before that comes back via new props, the 2nd
  # composition event starts. Without the `_inCompositionEvent` flag
  # stopping the re-render, the asynchronous update request will cause us
  # to re-render and blow away our newly started 2nd composition event.
  #
  # While we're in a composition event it's important that `_onDOMMutated`
  # still get fired so the selection gets updated and the latest body
  # saved for the next render. However, we want to disable any plugins
  # since they may inadvertently kill the composition editor by mutating
  # the DOM.
  _onCompositionStart: =>
    @_inCompositionEvent = true
    @_teardownNonMutationListeners()

  _onCompositionEnd: =>
    @_inCompositionEvent = false
    @_setupNonMutationListeners()

  _onShowContextMenu: (event) =>
    @refs["toolbarController"]?.forceClose()
    event.preventDefault()

    {remote} = require('electron')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')

    menu = new Menu()

    @dispatchEventToExtensions("onShowContextMenu", event, {menu})
    menu.append(new MenuItem({ label: 'Cut', role: 'cut'}))
    menu.append(new MenuItem({ label: 'Copy', role: 'copy'}))
    menu.append(new MenuItem({ label: 'Paste', role: 'paste'}))
    menu.append(new MenuItem({ label: 'Paste and Match Style', click: =>
      NylasEnv.getCurrentWindow().webContents.pasteAndMatchStyle()
    }))
    menu.popup(remote.getCurrentWindow())


  ######################################################################
  ############################ Extensions ##############################
  ######################################################################

  _extensions: ->
    @props.extensions.concat(@coreExtensions)

  _runCallbackOnExtensions: (method, argsObj={}) =>
    for extension in @_extensions()
      @_runExtensionMethod(extension, method, argsObj)

  # Will execute the event handlers on each of the registerd and core
  # extensions In this context, event.preventDefault and
  # event.stopPropagation don't refer to stopping default DOM behavior or
  # prevent event bubbling through the DOM, but rather prevent our own
  # Contenteditable default behavior, and preventing other extensions from
  # being called. If any of the extensions calls event.preventDefault()
  # it will prevent the default behavior for the Contenteditable, which
  # basically means preventing the core extension handlers from being
  # called.  If any of the extensions calls event.stopPropagation(), it
  # will prevent any other extension handlers from being called.
  dispatchEventToExtensions: (method, event, args={}) =>
    argsObj = _.extend(args, {event})
    for extension in @props.extensions
      break if event?.isPropagationStopped()
      @_runExtensionMethod(extension, method, argsObj)

    return if event?.defaultPrevented or event?.isPropagationStopped()
    for extension in @coreExtensions
      break if event?.isPropagationStopped()
      @_runExtensionMethod(extension, method, argsObj)

  _runExtensionMethod: (extension, method, argsObj={}) =>
    return if @_inCompositionEvent
    return if not extension[method]?
    editingFunction = extension[method].bind(extension)
    @atomicEdit(editingFunction, argsObj)


  ######################################################################
  ############################# Selection ##############################
  ######################################################################
  # Saving and restoring a selection is difficult with React.
  #
  # React only handles Input and Textarea elements:
  # https://github.com/facebook/react/blob/master/src/browser/ui/ReactInputSelection.js
  # This is because they expose a very convenient `selectionStart` and
  # `selectionEnd` integer.
  #
  # Contenteditable regions are trickier. They require the more
  # sophisticated `Range` and `Selection` APIs. We have an
  # {ExtendedSelection} class which is a wrapper around the native DOM
  # Selection API. This exposes convenience methods for manipulating the
  # Selection object.
  #
  # Range docs:
  # http://www.w3.org/TR/DOM-Level-2-Traversal-Range/ranges.html
  #
  # Selection API docs:
  # http://www.w3.org/TR/selection-api/#dfn-range
  #
  # A Contenteditable region can have arbitrary html inside of it. This
  # means that a selection start point can be some node (the `anchorNode`)
  # and its end point can be a completely different node (the `focusNode`)
  #
  # When React re-renders, all of the DOM nodes may change. They may
  # look exactly the same, but have different object references.
  #
  # This means that your old references to `anchorNode` and `focusNode`
  # may be bad and no longer in scope or painted.
  #
  # In order to restore the selection properly we need to re-find the
  # equivalent `anchorNode` and `focusNode`. Luckily we can use the
  # `isEqualNode` method to get a shallow comparison of the nodes.
  #
  # Unfortunately it's possible for `isEqualNode` to match more than one
  # node since two nodes may look very similar.
  #
  # To fix this we need to keep track of the original indices to determine
  # which node is most likely the matching one.
  #
  # http://www.w3.org/TR/selection-api/#selectstart-event

  ## TODO DEPRECATE ME: This is only necessary because Undo/Redo is still
  #part of the composer and not a core part of the Contenteditable.
  getCurrentSelection: => @innerState.exportedSelection
  getPreviousSelection: => @innerState.previousExportedSelection

  # Every time the selection changes we save its state.
  #
  # In an ideal world, the selection state, much like the body, would
  # behave like any other controlled React input: onchange we'd notify our
  # parent, they'd update our props, and we'd re-render.
  #
  # Unfortunately, Selection is not something React natively keeps track
  # of in its virtual DOM, the performance would be terrible if we
  # re-rendered on every selection change (think about dragging a
  # selection), and having every user of `<Contenteditable>` need to
  # remember to deal with, save, and set the Selection object is a pain.
  #
  # To counter this we save local instance copies of the Selection.
  #
  # First of all we wrap the native Selection object in an
  # [ExtendedSelection} object. This is a pure extension and has all
  # standard methods.
  #
  # We then save out 3 types of selections on `innerState` for us to use
  # later:
  #
  # 1. `selectionSnapshot` - This is accessed by any sub-components of
  # the Contenteditable such as the `<FloatingToolbar>` and its
  # extensions.
  #
  # It is slightly different from an `exportedSelection` in that the
  # anchorNode property points to an attached DOM reference and not the
  # clone of a node. This is necessary for extensions to be able to
  # traverse the actual current DOM from the anchorNode. The
  # `exportedSelection`'s, cloned nodes don't have parentNOdes.
  #
  # This is crucially not a reference to the `rawSelection` object,
  # because the anchorNodes of that may change from underneath us at any
  # time.
  #
  # 2. `exportedSelection` - This is an {ExportedSelection} object and is
  # used to restore the selection even after the DOM has changed. When our
  # component re-renders the actual DOM objects on the heap will be
  # different. An {ExportedSelection} contains counting indicies we use to
  # re-find the correct DOM Nodes in the new document.
  #
  # 3. `previousExportedSelection` - This is used for undo / redo so when
  # you revert to a previous state, the selection updates as well.
  _saveSelection: =>
    selection = new ExtendedSelection(@_editableNode())
    return unless selection?.isInScope()

    @setInnerState
      selectionSnapshot: selection.selectionSnapshot()
      exportedSelection: selection.exportSelection()
      previousExportedSelection: @innerState.exportedSelection

  _restoreSelection: =>
    @_teardownNonMutationListeners()
    selection = new ExtendedSelection(@_editableNode())
    selection.importSelection(@innerState.exportedSelection)
    if selection.isInScope()
      @_onSelectionChanged(selection)
    @_setupNonMutationListeners()

  # When the component updates, the selection may have changed from our
  # last known saved position. This can happen for a couple of reasons:
  #
  # 1. Some sister-component (like the LinkEditor) grabbed the selection.
  # 2. A sister-component that used to have the selection was unmounted
  # causing the selection to be null or the document
  _shouldRestoreSelectionOnUpdate: ->
    (not @innerState.dragging) and
    (document.activeElement is @_editableNode() or
    not @_editableNode().parentNode.contains(document.activeElement))

  _onSelectionChanged: (selection) ->
    @props.onSelectionChanged(selection, @_editableNode())
    # The bounding client rect has changed
    @setInnerState editableNode: @_editableNode()

module.exports = Contenteditable
