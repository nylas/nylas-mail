# The `ComponentRegistry` allows you to add and remove React components.
{ComponentRegistry} = require 'nylas-exports'

PersonalLevelIcon = require './personal-level-icon'

# The `main.coffee` file (sometimes `main.cjsx`) is the file that initializes
# the entire package. It should export an object with some package life cycle
# methods.
module.exports =
  # This gets called on the package's initiation. This is the time to register
  # your React components to the `ComponentRegistry`.
  activate: (@state) ->
    # The `role` tells the `ComponentRegistry` where to put the React component.
    ComponentRegistry.register PersonalLevelIcon,
      role: 'ThreadListIcon'

  # This **optional** method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  deactivate: ->
    ComponentRegistry.unregister(PersonalLevelIcon)
