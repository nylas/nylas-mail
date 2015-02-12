{deprecate} = require 'grim'
_ = require 'underscore-plus'
{join} = require 'path'
{Model} = require 'theorist'
Q = require 'q'
Serializable = require 'serializable'
Delegator = require 'delegato'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
PaneContainer = require './pane-container'
Pane = require './pane'
Panel = require './panel'
PanelElement = require './panel-element'
PanelContainer = require './panel-container'
PanelContainerElement = require './panel-container-element'
ViewRegistry = require './view-registry'
WorkspaceElement = require './workspace-element-edgehill'

# Essential: Represents the state of the user interface for the entire window.
# An instance of this class is available via the `atom.workspace` global.
#
# Interact with this object to open files, be notified of current and future
# editors, and manipulate panes. To add panels, you'll need to use the
# {WorkspaceView} class for now until we establish APIs at the model layer.
#
# * `editor` {TextEditor} the new editor
#
module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @properties
    fullScreen: false

  constructor: (params) ->
    super
    @emitter = new Emitter

    atom.views.addViewProvider
      modelConstructor: Workspace
      viewConstructor: WorkspaceElement

  # Called by the Serializable mixin during deserialization
  deserializeParams: (params) ->
    for packageName in params.packagesWithActiveGrammars ? []
      atom.packages.getLoadedPackage(packageName)?.loadGrammarsSync()
    params

  # Called by the Serializable mixin during serialization.
  serializeParams: ->
    fullScreen: atom.isFullScreen()

  # Updates the application's title and proxy icon based on whichever file is
  # open.
  updateWindowTitle: ->
    ## TODO we might want to put the unread count here in the future.
    document.title = "Edgehill"

  confirmClose: ->
    true

  # A no-op in Edgehill Workspace
  open: ->

  # Appending Children to the Workspace
  # ----
  
  addColumnItem: (item, columnId="") ->
    item = atom.views.getView(item)
    container = atom.workspaceElement.horizontalAxis

    if columnId.length > 0
      parent = document.getElementById(columnId)
      if not parent?
        parent = document.createElement("div")
        parent.setAttribute("id", columnId)
        parent.setAttribute("class", "inbox-panel")
        container.appendChild(parent)
    else
      parent = container

    parent.appendChild(item)
    return item

  addRow: (item) ->
    item = atom.views.getView(item)
    container = atom.workspaceElement.verticalAxis
    container.appendChild(item)
