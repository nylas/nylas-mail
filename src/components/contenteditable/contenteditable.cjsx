_ = require 'underscore'
React = require 'react'

{Utils, DOMUtils} = require 'nylas-exports'
{KeyCommandsRegion} = require 'nylas-component-kit'
FloatingToolbarContainer = require './floating-toolbar-container'

EditorAPI = require './editor-api'
ExtendedSelection = require './extended-selection'

TabManager = require './tab-manager'
ListManager = require './list-manager'
MouseService = require './mouse-service'
DOMNormalizer = require './dom-normalizer'
ClipboardService = require './clipboard-service'

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

  coreExtensions: [DOMNormalizer, ListManager, TabManager]


  ########################################################################
  ########################### Public Methods #############################
  ########################################################################

  ### Public: perform an editing operation on the Contenteditable

  - `editingFunction` A function to mutate the DOM and
  {ExtendedSelection}. It gets passed an {EditorAPI} object that contains
  mutating methods.

  If the current selection at the time of running the extension is out of
  scope, it will be set to the last saved state. This ensures extensions
  operate on a valid {ExtendedSelection}.

  Edits made within the editing function will eventually fire _onDOMMutated
  ###
  atomicEdit: (editingFunction, extraArgs...) =>
    @_teardownListeners()

    editor = new EditorAPI(@_editableNode())

    if not editor.currentSelection().isInScope()
      editor.importSelection(@innerState.exportedSelection)

    args = [editor, extraArgs...]
    editingFunction.apply(null, args)

    @_setupListeners()

  focus: => @_editableNode().focus()

  selectEnd: => @atomicEdit (editor) -> editor.selectEnd()


  ########################################################################
  ########################### React Lifecycle ############################
  ########################################################################

  constructor: (@props) ->
    @innerState = {}
    @_mutationObserver = new MutationObserver(@_onDOMMutated)

  componentWillMount: =>
    @_setupServices()

  componentDidMount: =>
    @_setupListeners()
    @_mutationObserver.observe(@_editableNode(), @_mutationConfig())
    @setInnerState editableNode: @_editableNode()

  # When we have a composition event in progress, we should not update
  # because otherwise our composition event will be blown away.
  shouldComponentUpdate: (nextProps, nextState) ->
    not @_inCompositionEvent and
    (not Utils.isEqualReact(nextProps, @props) or
     not Utils.isEqualReact(nextState, @state))

  componentWillReceiveProps: (nextProps) =>
    if nextProps.initialSelectionSnapshot?
      @_saveSelectionState(nextProps.initialSelectionSnapshot)

  componentDidUpdate: =>
    @_restoreSelection()
    @_refreshServices()
    @_mutationObserver.disconnect()
    @_mutationObserver.observe(@_editableNode(), @_mutationConfig())
    @setInnerState
      links: @_editableNode().querySelectorAll("*[href]")
      editableNode: @_editableNode()

  componentWillUnmount: =>
    @_mutationObserver.disconnect()
    @_teardownListeners()
    @_teardownServices()

  setInnerState: (innerState={}) =>
    @innerState = _.extend @innerState, innerState
    @refs["toolbarController"]?.componentWillReceiveInnerProps(innerState)
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


  ########################################################################
  ############################### Render #################################
  ########################################################################

  render: =>
    <KeyCommandsRegion className="contenteditable-container"
                       localHandlers={@_keymapHandlers()}>
      {@_renderFloatingToolbar()}

      <div className="contenteditable"
           ref="contenteditable"
           contentEditable
           spellCheck={false}
           dangerouslySetInnerHTML={__html: @props.value}
           {...@_eventHandlers()}></div>
    </KeyCommandsRegion>

  _renderFloatingToolbar: ->
    return unless @props.floatingToolbar
    <FloatingToolbarContainer
        ref="toolbarController" atomicEdit={@atomicEdit} />

  _editableNode: =>
    React.findDOMNode(@refs.contenteditable)


  ########################################################################
  ############################ Listener Setup ############################
  ########################################################################

  _eventHandlers: =>
    handlers = {}
    _.extend(handlers, service.eventHandlers()) for service in @_services
    handlers = _.extend handlers,
      onBlur: @_onBlur
      onFocus: @_onFocus
      onKeyDown: @_onKeyDown
      onCompositionEnd: @_onCompositionEnd
      onCompositionStart: @_onCompositionStart
    return handlers

  _keymapHandlers: ->
    atomicEditWrap = (command) =>
      (event) =>
        @atomicEdit(((editor) -> editor[command]()), event)

    keymapHandlers = {
      'contenteditable:bold': atomicEditWrap("bold")
      'contenteditable:italic': atomicEditWrap("italic")
      'contenteditable:indent': atomicEditWrap("indent")
      'contenteditable:outdent': atomicEditWrap("outdent")
      'contenteditable:underline': atomicEditWrap("underline")
      'contenteditable:numbered-list': atomicEditWrap("insertOrderedList")
      'contenteditable:bulleted-list': atomicEditWrap("insertUnorderedList")
    }

    return keymapHandlers

  _setupListeners: =>
    document.addEventListener("selectionchange", @_onSelectionChange)
    @_editableNode().addEventListener('contextmenu', @_onShowContextMenu)

  _teardownListeners: =>
    document.removeEventListener("selectionchange", @_onSelectionChange)
    @_editableNode().removeEventListener('contextmenu', @_onShowContextMenu)

  # https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver
  _mutationConfig: ->
    subtree: true
    childList: true
    attributes: true
    characterData: true
    attributeOldValue: true
    characterDataOldValue: true


  ########################################################################
  ############################ Event Handlers ############################
  ########################################################################

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

    @_runCallbackOnExtensions("onContentChanged", mutations)

    @_saveSelectionState()

    @props.onChange(target: {value: @_editableNode().innerHTML})

    @_mutationObserver.observe(@_editableNode(), @_mutationConfig())
    return

  _onBlur: (event) =>
    @setInnerState dragging: false
    return if @_editableNode().parentElement.contains event.relatedTarget
    @dispatchEventToExtensions("onBlur", event)
    @setInnerState editableFocused: false

  _onFocus: (event) =>
    @setInnerState editableFocused: true
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
  _onCompositionStart: =>
    @_inCompositionEvent = true
    @_teardownListeners()

  _onCompositionEnd: =>
    @_inCompositionEvent = false
    @_setupListeners()

  _onShowContextMenu: (event) =>
    @refs["toolbarController"]?.forceClose()
    event.preventDefault()

    remote = require('remote')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')

    menu = new Menu()

    @dispatchEventToExtensions("onShowContextMenu", event, menu)
    menu.append(new MenuItem({ label: 'Cut', role: 'cut'}))
    menu.append(new MenuItem({ label: 'Copy', role: 'copy'}))
    menu.append(new MenuItem({ label: 'Paste', role: 'paste'}))
    menu.append(new MenuItem({ label: 'Paste and Match Style', click: =>
      NylasEnv.getCurrentWindow().webContents.pasteAndMatchStyle()
    }))
    menu.popup(remote.getCurrentWindow())


  ########################################################################
  ############################# Extensions ###############################
  ########################################################################

  _runCallbackOnExtensions: (method, args...) =>
    for extension in @props.extensions.concat(@coreExtensions)
      @_runExtensionMethod(extension, method, args...)

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
  dispatchEventToExtensions: (method, event, args...) =>
    for extension in @props.extensions
      break if event?.isPropagationStopped()
      @_runExtensionMethod(extension, method, event, args...)

    return if event?.defaultPrevented or event?.isPropagationStopped()
    for extension in @coreExtensions
      break if event?.isPropagationStopped()
      @_runExtensionMethod(extension, method, event, args...)

  _runExtensionMethod: (extension, method, args...) =>
    return if not extension[method]?
    editingFunction = extension[method].bind(extension)
    @atomicEdit(editingFunction, args...)


  ########################################################################
  ############################## Selection ###############################
  ########################################################################
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

  getCurrentSelection: => @innerState.exportedSelection ? {}
  getPreviousSelection: => @innerState.previousExportedSelection ? {}

  # Every time the cursor changes we need to save its location and state.
  #
  # When React re-renders it doesn't restore the Selection. We need to do
  # this manually with `_restoreSelection`
  #
  # As a performance optimization, we don't attach this to React `state`.
  # Since re-rendering generates new DOM objects on the heap, testing for
  # selection equality is expensive and requires a full tree walk.
  #
  # We also need to keep references to the previous selection state in
  # order for undo/redo to work properly.
  _saveSelectionState: (exportedStateToSave=null) =>
    extendedSelection = new ExtendedSelection(@_editableNode())
    if exportedStateToSave
      extendedSelection.importSelection(exportedStateToSave)
    return unless extendedSelection?.isInScope()
    return if (@innerState.exportedSelection?.isEqual(extendedSelection))

    @setInnerState
      exportedSelection: extendedSelection.exportSelection()
      editableFocused: true
      previousExportedSelection: @innerState.exportedSelection

    @_onSelectionChanged(extendedSelection)

  _onSelectionChange: (event) => @_saveSelectionState()

  _restoreSelection: =>
    return unless @_shouldRestoreSelection()
    @_teardownListeners()
    extendedSelection = new ExtendedSelection(@_editableNode())
    extendedSelection.importSelection(@innerState.exportedSelection)
    if extendedSelection.isInScope()
      @_onSelectionChanged(extendedSelection)
    @_setupListeners()

  _shouldRestoreSelection: ->
    (not @innerState.dragging) and
    document.activeElement is @_editableNode()

  _onSelectionChanged: (selection) ->
    @props.onSelectionChanged(selection, @_editableNode())
    # The bounding client rect has changed
    @setInnerState editableNode: @_editableNode()

module.exports = Contenteditable
