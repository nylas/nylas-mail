React = require 'react'
ComponentRegistry = require '../src/component-registry'

dummy_component = new ComponentRegistry.Component
  name: 'dummy-component'
  view: ->
  role: 'button'

describe 'a Component', ->
  it 'should not construct if a name or view is unspecified', ->
    expect(-> ComponentRegistry.Component()).toThrow()

  it 'should construct if there is both a name and a view', ->
    i = ComponentRegistry.Component
      name: 'reply-button'
      view: ->
    expect(i).toBeDefined()

describe 'ComponentRegistry', ->
  beforeEach ->
    ComponentRegistry._clear()

  describe '.register()', ->
    it 'throws an exception if passed a non-component', ->
      expect(-> ComponentRegistry.register(null)).toThrow()
      expect(-> ComponentRegistry.register("cheese")).toThrow()

    it 'returns itself', ->
      expect(ComponentRegistry.register dummy_component).toBe(ComponentRegistry)

    it 'does not allow a component to be registered twice', ->
      ComponentRegistry.register dummy_component
      expect(-> ComponentRegistry.register dummy_component).toThrow()

  describe '.getByName()', ->
    it 'should return a component', ->
      ComponentRegistry.register dummy_component
      expect(ComponentRegistry.getByName dummy_component.name).toEqual dummy_component

    it 'should throw an exception if a component is undefined', ->
      expect(-> ComponentRegistry.getByName "not actually a name").toThrow()

  describe '.findByName()', ->
    it 'should return a component', ->
      ComponentRegistry.register dummy_component
      expect(ComponentRegistry.findByName dummy_component.name).toEqual dummy_component

    it 'should return undefined if there is no component', ->
      expect(ComponentRegistry.findByName "not actually a name").toBeUndefined()

    it 'should return an alternate if there is no component, and an alt', ->
      alt = "alt"
      expect(ComponentRegistry.findByName "not actually a name", alt).toBe alt

  describe '.findViewByName()', ->
    it 'should return a component view', ->
      ComponentRegistry.register dummy_component
      expect(ComponentRegistry.findViewByName dummy_component.name).toEqual dummy_component.view

    it 'should return undefined if there is no component', ->
      expect(ComponentRegistry.findViewByName "not actually a name").toBeUndefined()

    it 'should return an alternate if there is no component, and an alt', ->
      alt = "alt"
      expect(ComponentRegistry.findViewByName "not actually a name", alt).toBe alt

  describe '.findAllByRole()', ->
    it 'should return a list of matching components', ->
      ComponentRegistry.register dummy_component
      expect(ComponentRegistry.findAllByRole 'button').toEqual [dummy_component]

    it 'should return an empty list for non-matching components', ->
      expect(ComponentRegistry.findAllByRole 'dummy').toEqual []

  describe '.findAllViewsByRole()', ->
    it 'should return a list of matching components', ->
      ComponentRegistry.register dummy_component
      expect(ComponentRegistry.findAllViewsByRole 'button').toEqual [dummy_component.view]

    it 'should return an empty list for non-matching components', ->
      expect(ComponentRegistry.findAllViewsByRole 'dummy').toEqual []

  describe '.unregister()', ->
    it 'unregisters the component if it exists', ->
      ComponentRegistry.register dummy_component
      ComponentRegistry.unregister dummy_component.name
      expect(ComponentRegistry.findByName dummy_component.name).toBeUndefined()

    it 'notifies of an error if an invalid component is unregistered', ->
      ComponentRegistry.register dummy_component
      unregistered = ComponentRegistry.unregister "something-else"
      expect(ComponentRegistry.findByName dummy_component.name).toEqual dummy_component

