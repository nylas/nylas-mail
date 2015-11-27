ExtensionRegistry = require '../src/extension-registry'

class TestExtension
  @name: 'TestExtension'

describe 'ExtensionRegistry', ->
  beforeEach ->
    @originalAdapters = ExtensionRegistry._deprecationAdapters
    @registry = new ExtensionRegistry.Registry('Test')
    spyOn @registry, 'triggerDebounced'

  describe 'Registry', ->
    it 'has trigger and listen to defined', ->
      expect(@registry.trigger).toBeDefined()
      expect(@registry.listen).toBeDefined()
      expect(@registry.listenTo).toBeDefined()

    describe 'register', ->
      it 'throws an exception if extension not passed', ->
        expect(=> @registry.register(null)).toThrow()

      it 'throws an exception if extension does not have a name', ->
        expect(=> @registry.register({})).toThrow()

      it 'throws an exception if extension is array', ->
        expect(=> @registry.register([])).toThrow()

      it 'throws an exception if extension is string', ->
        expect(=> @registry.register('')).toThrow()

      it 'returns itself', ->
        expect(@registry.register(TestExtension)).toBe(@registry)

      it 'registers extension and triggers', ->
        @registry.register(TestExtension)
        expect(@registry.extensions().length).toEqual 1
        expect(@registry.triggerDebounced).toHaveBeenCalled()

      it 'does not add extensions with the same name', ->
        expect(@registry.extensions().length).toEqual 0
        @registry.register(TestExtension)
        expect(@registry.extensions().length).toEqual 1
        @registry.register({name: 'TestExtension'})
        expect(@registry.extensions().length).toEqual 1

      it 'calls deprecationAdapters if present for a role', ->
        adapterSpy = jasmine.createSpy('adapterSpy').andCallFake (ext) -> ext
        @registry = new ExtensionRegistry.Registry('Test', adapterSpy)
        spyOn @registry, 'triggerDebounced'
        @registry.register(TestExtension)
        expect(adapterSpy.calls.length).toEqual 1

    describe 'unregister', ->
      it 'unregisters the extension if it exists', ->
        @registry.register(TestExtension)
        @registry.unregister(TestExtension)
        expect(@registry.extensions().length).toEqual 0

      it 'throws if invalid extension passed', ->
        expect( => @registry.unregister('Test')).toThrow()
        expect( => @registry.unregister(null)).toThrow()
        expect( => @registry.unregister([])).toThrow()
        expect( => @registry.unregister({})).toThrow()
