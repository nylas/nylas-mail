Reflux = require 'reflux'
_ = require 'underscore-plus'

# Error types
class RegistryError extends Error

# Event types
class ComponentRegistryEvent
class ComponentAdded extends ComponentRegistryEvent
  constructor: (@component) ->

getViewsByName = (components) ->
  state = {}
  for component in components ? []
    # Allow components to be requested as "Component" or "Component as C"
    [registered, requested] = component.split " as "
    requested ?= registered
    state[requested] = ComponentRegistry.findViewByName registered
  state

Mixin =
  getInitialState: ->
    getViewsByName(@components)

  componentWillMount: ->
    @_componentUnlistener = ComponentRegistry.listen (event) =>
      @setState getViewsByName(@components)

  componentDidUnmount: ->
    @_componentUnlistener()

# Internal representation of components
class Component
  constructor: (attributes) ->
    # Don't shit the bed if the user forgets `new`
    return new Component(attributes) unless @ instanceof Component

    ['name', 'model', 'view', 'role'].map (key) =>
      @[key] = attributes[key] if attributes[key]

    unless @name?
      throw new RegistryError 'Required: name argument'
    unless @view?
      throw new RegistryError 'Required: view argument'

# Avoid direct access to the registry
registry = {}

ComponentRegistry = Reflux.createStore
  register: (component) ->
    # Receive a component or something which can build one
    throw new RegistryError 'Required: ComponentRegistry.Component or something which conforms to {name, view}' unless component instanceof Object
    component = new Component(component) unless component instanceof Component
    if component.name in Object.keys(registry)
      throw new RegistryError "Error: Tried to register #{component.name} twice"
    registry[component.name] = component
    # Trigger listeners
    @trigger new ComponentAdded(component)
    # Return `this` for chaining
    @

  unregister: (name) -> delete registry[name]

  getByName: (name) ->
    component = registry[name]
    throw new RegistryError 'No such component' unless component?
    component

  findByName: (name, alt) ->
    registry[name] ? alt

  findViewByName: (name, alt) ->
    registry[name]?.view ? alt

  findAllByRole: (role) ->
    _.filter (_.values registry), (component) ->
      component.role == role

  findAllViewsByRole: (role) ->
    _.map @findAllByRole(role), (component) -> component.view

  _clear: ->
    registry = {}

  Component: Component
  RegistryError: RegistryError
  ComponentRegistryEvent: ComponentRegistryEvent
  ComponentAdded: ComponentAdded
  Mixin: Mixin

module.exports = ComponentRegistry
