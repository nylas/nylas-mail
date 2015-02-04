ipc = require 'ipc'
path = require 'path'
{Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
scrollbarStyle = require 'scrollbar-style'
{callAttachHooks} = require 'space-pen'

module.exports =
class WorkspaceElement extends HTMLElement

  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @initializeContent()
    @observeScrollbarStyle()

  attachedCallback: ->
    callAttachHooks(this)
    @focus()

  detachedCallback: ->
    @subscriptions.dispose()
    @model.destroy()

  initializeContent: ->
    @classList.add 'workspace'
    @setAttribute 'tabindex', -1

    @horizontalAxis = document.createElement('atom-workspace-axis')
    @horizontalAxis.classList.add('horizontal')
    
    @horizontalContainer = document.createElement('div')
    @horizontalContainer.classList.add('atom-workspace-axis-container')
    @horizontalContainer.appendChild(@horizontalAxis)

    @verticalAxis = document.createElement('atom-workspace-axis')
    @verticalAxis.classList.add('vertical')
    @verticalAxis.appendChild(@horizontalContainer)

    @appendChild(@verticalAxis)

  observeScrollbarStyle: ->
    @subscriptions.add scrollbarStyle.onValue (style) =>
      switch style
        when 'legacy'
          @classList.remove('scrollbars-visible-when-scrolling')
          @classList.add("scrollbars-visible-always")
        when 'overlay'
          @classList.remove('scrollbars-visible-always')
          @classList.add("scrollbars-visible-when-scrolling")

  getModel: ->
    @model

  setModel: (@model) ->

atom.commands.add 'atom-workspace',
  'application:show-main-window': -> ipc.send('command', 'application:show-main-window')
  'application:new-message': -> ipc.send('command', 'application:new-message')
  'application:about': -> ipc.send('command', 'application:about')
  'application:run-all-specs': -> ipc.send('command', 'application:run-all-specs')
  'application:run-benchmarks': -> ipc.send('command', 'application:run-benchmarks')
  'application:show-settings': -> ipc.send('command', 'application:show-settings')
  'application:quit': -> ipc.send('command', 'application:quit')
  'application:hide': -> ipc.send('command', 'application:hide')
  'application:hide-other-applications': -> ipc.send('command', 'application:hide-other-applications')
  'application:install-update': -> ipc.send('command', 'application:install-update')
  'application:unhide-all-applications': -> ipc.send('command', 'application:unhide-all-applications')
  'application:minimize': -> ipc.send('command', 'application:minimize')
  'application:zoom': -> ipc.send('command', 'application:zoom')
  'application:bring-all-windows-to-front': -> ipc.send('command', 'application:bring-all-windows-to-front')
  'window:run-package-specs': -> ipc.send('run-package-specs', path.join(atom.project.getPath(), 'spec'))

module.exports = WorkspaceElement = document.registerElement 'atom-workspace', prototype: WorkspaceElement.prototype
