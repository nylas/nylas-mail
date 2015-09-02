SpellcheckDraftStoreExtension = require '../lib/draft-extension'
fs = require 'fs'
_ = require 'underscore'

initialHTML = fs.readFileSync(__dirname + '/fixtures/california-with-misspellings-before.html').toString()
expectedHTML = fs.readFileSync(__dirname + '/fixtures/california-with-misspellings-after.html').toString()

describe "SpellcheckDraftStoreExtension", ->
  beforeEach ->
    # Avoid differences between node-spellcheck on different platforms
    spellings = JSON.parse(fs.readFileSync(__dirname + '/fixtures/california-spelling-lookup.json'))
    spyOn(SpellcheckDraftStoreExtension, 'isMisspelled').andCallFake (word) ->
      spellings[word]

  describe "walkTree", ->
    it "correctly walks a DOM tree and surrounds mispelled words", ->
      dom = document.createElement('div')
      dom.innerHTML = initialHTML
      SpellcheckDraftStoreExtension.walkTree(dom)
      expect(dom.innerHTML).toEqual(expectedHTML)

  describe "finalizeSessionBeforeSending", ->
    it "removes the annotations it inserted", ->
      session =
        draft: ->
          body: expectedHTML
        changes:
          add: jasmine.createSpy('add')

      SpellcheckDraftStoreExtension.finalizeSessionBeforeSending(session)
      expect(session.changes.add).toHaveBeenCalledWith(body: initialHTML)

module.exports = SpellcheckDraftStoreExtension
