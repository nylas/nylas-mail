_ = require 'underscore-plus'
GithubSidebar = require "./github-sidebar"
{ComponentRegistry,
 WorkspaceStore} = require "nylas-exports"

module.exports =
  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  #
  activate: (@state={}) ->
    # Register our sidebar so that it appears in the Message List sidebar.
    # This sidebar is to the right of the Message List in both split pane mode
    # and list mode.
    ComponentRegistry.register GithubSidebar,
      location: WorkspaceStore.Location.MessageListSidebar

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
    # Unregister our component
    ComponentRegistry.unregister(GithubSidebar)
