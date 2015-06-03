{Utils, React, ComponentRegistry} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class MyButton extends React.Component

  # Adding a `displayName` makes debugging React easier
  @displayName: 'MyButton'

  render: =>
    <div className="my-package">
      <button className="btn btn-toolbar" onClick={@_onClick}>
        Hello World
      </button>
    </div>
  #
  _onClick: =>
    dialog = require('remote').require('dialog')
    dialog.showErrorBox('Success!', 'Button was clicked.')

module.exports =
  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  #
  activate: (@state) ->
    ComponentRegistry.register MyButton,
      role: 'Composer:ActionButton'

  # Serialize is called when your package is about to be unmounted.
  # You can return a state object that will be passed back to your package
  # when it is re-activated.
  #
  serialize: ->

  # This **optional** method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  #
  deactivate: ->
    ComponentRegistry.unregister(MyButton)
