MetadataStore = require '../../src/flux/stores/metadata-store'
describe "MetadataStore", ->
  beforeEach: ->
    spyOn(atom, "isMainWindow").andReturn(true)
