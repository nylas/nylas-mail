React = require 'react'
ComponentRegistry = require '../src/component-registry'

class TestComponent extends React.Component
  @displayName: 'TestComponent'
  constructor: ->

class TestComponentNoDisplayName extends React.Component
  constructor: ->

class AComponent extends React.Component
  @displayName: 'A'

class BComponent extends React.Component
  @displayName: 'B'

class CComponent extends React.Component
  @displayName: 'C'

class DComponent extends React.Component
  @displayName: 'D'

class EComponent extends React.Component
  @displayName: 'E'

class FComponent extends React.Component
  @displayName: 'F'

describe 'ComponentRegistry', ->
  beforeEach ->
    ComponentRegistry._clear()

  describe 'register', ->
    it 'throws an exception if passed a non-component', ->
      expect(-> ComponentRegistry.register(null)).toThrow()
      expect(-> ComponentRegistry.register("cheese")).toThrow()

    it 'returns itself', ->
      expect(ComponentRegistry.register(TestComponent, {role: "bla"})).toBe(ComponentRegistry)

    it 'does not allow components to be overridden by others with the same displayName', ->
      ComponentRegistry.register(TestComponent, {role: "bla"})
      expect(-> ComponentRegistry.register(TestComponent, {role: "bla"})).toThrow()

    it 'does not allow components to be registered without a displayName', ->
      expect(-> ComponentRegistry.register(TestComponentNoDisplayName, {role: "bla"})).toThrow()

  describe 'findComponentByName', ->
    it 'should return a component', ->
      ComponentRegistry.register(TestComponent, {role: "bla"})
      expect(ComponentRegistry.findComponentByName('TestComponent')).toEqual(TestComponent)

    it 'should return undefined if there is no component', ->
      expect(ComponentRegistry.findComponentByName("not actually a name")).toBeUndefined()

  describe 'findComponentsMatching', ->
    it 'should throw if a descriptor is not provided', ->
      expect( -> ComponentRegistry.findComponentsMatching()).toThrow()

    it 'should return the correct results in a wide range of test cases', ->
      StubLocation1 =
        id: 'StubLocation1'
      StubLocation2 =
        id: 'StubLocation2'
      ComponentRegistry.register(AComponent, { role: 'ThreadAction' })
      ComponentRegistry.register(BComponent, { role: 'ThreadAction', modes: ['list'] })
      ComponentRegistry.register(CComponent, { location: StubLocation1, modes: ['split'] })
      ComponentRegistry.register(DComponent, { locations: [StubLocation1, StubLocation2] })
      ComponentRegistry.register(EComponent, { roles: ['ThreadAction', 'MessageAction'] })
      ComponentRegistry.register(FComponent, { roles: ['MessageAction'], mode: 'list' })

      scenarios = [
        {descriptor: {role: 'ThreadAction'}, results: [AComponent, BComponent, EComponent]}
        {descriptor: {role: 'ThreadAction', mode: 'list'}, results: [AComponent, BComponent, EComponent]}
        {descriptor: {role: 'ThreadAction', mode: 'split'}, results: [AComponent, EComponent]}
        {descriptor: {location: StubLocation1}, results: [CComponent, DComponent]}
        {descriptor: {location: StubLocation1, mode: 'list'}, results: [DComponent]}
        {descriptor: {locations: [StubLocation1, StubLocation2]}, results: [CComponent, DComponent]}
        {descriptor: {roles: ['ThreadAction', 'MessageAction']}, results: [AComponent, BComponent, EComponent, FComponent]}
      ]

      scenarios.forEach ({descriptor, results}) ->
        expect(ComponentRegistry.findComponentsMatching(descriptor)).toEqual(results)


  describe 'unregister', ->
    it 'unregisters the component if it exists', ->
      ComponentRegistry.register(TestComponent, { role: 'bla' })
      ComponentRegistry.unregister(TestComponent)
      expect(ComponentRegistry.findComponentByName('TestComponent')).toBeUndefined()

    it 'throws if a string is passed instead of a component', ->
      expect( -> ComponentRegistry.unregister('TestComponent')).toThrow()
