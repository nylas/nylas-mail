_ = require 'underscore-plus'
Actions = require './flux/actions'

{Listener, Publisher} = require './flux/modules/reflux-coffee'
CoffeeHelpers = require './flux/coffee-helpers'

# Error types
class RegistryError extends Error


# Internal representation of components
class Component
  constructor: (attributes) ->
    # Don't shit the bed if the user forgets `new`
    return new Component(attributes) unless @ instanceof Component

    ['name', 'model', 'view', 'role', 'mode', 'location'].map (key) =>
      @[key] = attributes[key] if attributes[key]

    unless @name?
      throw new RegistryError 'Required: name argument'
    unless @view?
      throw new RegistryError 'Required: view argument'

# Avoid direct access to the registry
registry = {}


###
Public: The ComponentRegistry maintains an index of React components registered
by Nylas packages. Components can use {InjectedComponent} and {InjectedComponentSet}
to dynamically render components registered with the ComponentRegistry.
###
class ComponentRegistry
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @_showComponentRegions = false
    @listenTo Actions.toggleComponentRegions, @_onToggleComponentRegions


  # Public: Register a new component with the Component Registry.
  # Typically, packages call this method from their main `activate` method
  # to extend the Nylas user interface, and call the corresponding `unregister`
  # method in `deactivate`.
  #
  # * `component` {Object} with the following keys:
  #   * `name`: {String} name of your component. Must be globally unique.
  #   * `view`: {React.Component} The React Component you are registering.
  #   * `role`: (optional) {String} If you want to display your component in a location
  #      desigated by a role, pass the role identifier.
  #   * `mode`: (optional) {React.Component} If your component should only be displayed
  #      in a particular Workspace Mode, pass the mode. ('list' or 'split')
  #   * `location`: (optional) {Object} If your component should be displayed in a
  #      column or toolbar, pass the fully qualified location object, such as:
  #      `WorkspaceStore.Location.ThreadList`
  #
  # This method is chainable.
  #
  register: (component) =>
    # Receive a component or something which can build one
    throw new RegistryError 'Required: ComponentRegistry.Component or something which conforms to {name, view}' unless component instanceof Object
    component = new Component(component) unless component instanceof Component
    if component.name in Object.keys(registry)
      throw new RegistryError "Error: Tried to register #{component.name} twice"
    registry[component.name] = component

    # Trigger listeners. It's very important the component registry is debounced.
    # During app launch packages register tons of components and if we re-rendered
    # the entire UI after each registration it takes forever to load the UI.
    @triggerDebounced()

    # Return `this` for chaining
    @

  unregister: (name) => delete registry[name]

  showComponentRegions: =>
    @_showComponentRegions

  getByName: (name) =>
    component = registry[name]
    throw new RegistryError 'No such component' unless component?
    component

  # Public: Retrieve the registry entry for a given name.
  #
  # - `name`: The {String} name of the registered component to retrieve.
  #
  # Returns a {React.Component}
  #
  findByName: (name, alt) =>
    registry[name] ? alt

  findViewByName: (name, alt) =>
    registry[name]?.view ? alt

  # Public: Retrieve all of the registry entries for a given role.
  #
  # - `role`: The {String} role.
  #
  # Returns an {Array} of {React.Component} objects
  #
  findAllByRole: (role) =>
    _.filter (_.values registry), (component) ->
      component.role == role

  findAllViewsByRole: (role) =>
    _.map @findAllByRole(role), (component) -> component.view

  findAllByLocationAndMode: (location, mode) =>
    _.filter (_.values registry), (component) ->
      return false unless component.location
      return false if component.location.id isnt location.id
      return false if component.mode and component.mode isnt mode
      true

  triggerDebounced: _.debounce(( -> @trigger(@)), 1)

  _clear: =>
    registry = {}

  _onToggleComponentRegions: ->
    @_showComponentRegions = !@_showComponentRegions
    @trigger(@)

  Component: Component
  RegistryError: RegistryError

module.exports = new ComponentRegistry()
