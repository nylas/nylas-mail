_ = require 'underscore'
Actions = require './flux/actions'

{Listener, Publisher} = require './flux/modules/reflux-coffee'
CoffeeHelpers = require './flux/coffee-helpers'

###
Public: The ComponentRegistry maintains an index of React components registered
by Nylas packages. Components can use {InjectedComponent} and {InjectedComponentSet}
to dynamically render components registered with the ComponentRegistry.

Section: Stores

###
class ComponentRegistry
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @_registry = {}
    @_showComponentRegions = false

    @listenTo Actions.toggleComponentRegions, @_onToggleComponentRegions


  # Public: Register a new component with the Component Registry.
  # Typically, packages call this method from their main `activate` method
  # to extend the Nylas user interface, and call the corresponding `unregister`
  # method in `deactivate`.
  #
  # * `component` {Object} A React Component with a `displayName`
  # * `options` {Object}:
  #
  #   * `role`: (optional) {String} If you want to display your component in a location
  #      desigated by a role, pass the role identifier.
  #
  #   * `modes`: (optional) {Array} If your component should only be displayed
  #      in particular Workspace Modes, pass an array of supported modes.
  #      ('list', 'split', etc.)
  #
  #   * `location`: (optional) {Object} If your component should be displayed in a
  #      column or toolbar, pass the fully qualified location object, such as:
  #      `WorkspaceStore.Location.ThreadList`
  #
  #   Note that for advanced use cases, you can also pass (`modes`, `roles`, `locations`)
  #   with arrays instead of single values.
  #
  # This method is chainable.
  #
  register: (component, options) =>
    if component.view?
      return console.warn("Ignoring component trying to register with old CommandRegistry.register syntax")

    throw new Error("ComponentRegistry.register() requires `options` that describe the component") unless options
    throw new Error("ComponentRegistry.register() requires `component`, a React component") unless component
    throw new Error("ComponentRegistry.register() requires that your React Component defines a `displayName`") unless component.displayName

    {locations, modes, roles} = @_pluralizeDescriptor(options)

    throw new Error("ComponentRegistry.register() requires `role` or `location`") if not roles and not locations

    if @_registry[component.displayName] and @_registry[component.displayName].component isnt component
      throw new Error("ComponentRegistry.register(): A different component was already registered with the name #{component.displayName}")

    @_registry[component.displayName] = {component, locations, modes, roles}

    # Trigger listeners. It's very important the component registry is debounced.
    # During app launch packages register tons of components and if we re-rendered
    # the entire UI after each registration it takes forever to load the UI.
    @triggerDebounced()

    # Return `this` for chaining
    @

  unregister: (component) =>
    if _.isString(component)
      throw new Error("ComponentRegistry.unregister() must be called with a component.")
    delete @_registry[component.displayName]
    @triggerDebounced()

  # Public: Retrieve the registry entry for a given name.
  #
  # - `name`: The {String} name of the registered component to retrieve.
  #
  # Returns a {React.Component}
  #
  findComponentByName: (name) =>
    @_registry[name]?.component

  ###
  Public: Retrieve all of the registry entries matching a given descriptor.

  ```coffee
    ComponentRegistry.findComponentsMatching({
      role: 'Composer:ActionButton'
    })

    ComponentRegistry.findComponentsMatching({
      location: WorkspaceStore.Location.RootSidebar.Toolbar
    })
  ```

  - `descriptor`: An {Object} that specifies set of components using the
    available keys below.

    * `mode`: (optional) {String} Components that specifically list modes
       will only be returned if they include this mode.

    * `role`: (optional) {String} Only return components that have registered
       for this role.

    * `location`: (optional) {Object} Only return components that have registered
       for this location.

    Note that for advanced use cases, you can also pass (`modes`, `roles`, `locations`)
    with arrays instead of single values.

  Returns an {Array} of {React.Component} objects
  ###
  findComponentsMatching: (descriptor) =>
    if not descriptor?
      throw new Error("ComponentRegistry.findComponentsMatching called without descriptor")

    {locations, modes, roles} = @_pluralizeDescriptor(descriptor)

    if not locations and not modes and not roles
      throw new Error("ComponentRegistry.findComponentsMatching called with an empty descriptor")

    # Made into a convenience function because default
    # values (`[]`) are necessary and it was getting messy.
    overlaps = (entry = [], search = []) ->
      _.intersection(entry, search).length > 0

    entries = _.values @_registry
    entries = _.filter entries, (entry) ->
      if modes and entry.modes and not overlaps(modes, entry.modes)
        return false
      if locations and not overlaps(locations, entry.locations)
        return false
      if roles and not overlaps(roles, entry.roles)
        return false
      return true

    _.map entries, (entry) -> entry.component

  triggerDebounced: _.debounce(( -> @trigger(@)), 1)


  _pluralizeDescriptor: (descriptor) ->
    {locations, modes, roles} = descriptor
    modes = [descriptor.mode] if descriptor.mode
    roles = [descriptor.role] if descriptor.role
    locations = [descriptor.location] if descriptor.location
    {locations, modes, roles}

  _clear: =>
    @_registry = {}

  # Showing Component Regions

  _onToggleComponentRegions: ->
    @_showComponentRegions = !@_showComponentRegions
    @trigger(@)

  showComponentRegions: =>
    @_showComponentRegions


module.exports = new ComponentRegistry()
