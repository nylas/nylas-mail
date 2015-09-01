Message = require '../../src/flux/models/message'
Thread = require '../../src/flux/models/thread'
Label = require '../../src/flux/models/label'
_ = require 'underscore'

describe 'Thread', ->
  describe '.sortLabels()', ->
    getSortedLabels = (inputs) ->
      labels = _.map inputs, (i) ->
        new Label(name: i, displayName: i)
      thread = new Thread(labels: labels)
      return thread.sortedLabels()

    it "puts 'important' label first, if it's present", ->
      inputs = ['alphabetically before important', 'important']
      actualOut = getSortedLabels inputs
      expect(actualOut[0].displayName).toBe 'important'

    it "ignores 'important' label if not present", ->
      inputs = ['not important']
      actualOut = getSortedLabels inputs
      expect(actualOut.length).toBe 1
      expect(actualOut[0].displayName).toBe 'not important'

    it "doesn't display 'sent', 'all', 'archive', or 'drafts'", ->
      inputs = ['sent', 'all', 'archive', 'drafts']
      actualOut = getSortedLabels inputs
      expect(actualOut.length).toBe 0

    it "displays standard category names which aren't hidden next, if they're present", ->
      inputs = ['inbox', 'important', 'social']
      actualOut = _.pluck getSortedLabels(inputs), 'displayName'
      expectedOut = ['important', 'inbox', 'social']
      expect(actualOut).toEqual expectedOut

    it "ignores standard category names if they aren't present", ->
      inputs = ['social', 'work', 'important']
      actualOut = _.pluck getSortedLabels(inputs), 'displayName'
      expectedOut = ['important', 'social', 'work']
      expect(actualOut).toEqual expectedOut

    it "puts user-added categories at the end", ->
      inputs = ['food', 'inbox']
      actualOut = _.pluck getSortedLabels(inputs), 'displayName'
      expectedOut = ['inbox', 'food']
      expect(actualOut).toEqual expectedOut

    it "sorts user-added categories by displayName", ->
      inputs = ['work', 'social', 'receipts', 'important', 'inbox']
      actualOut = _.pluck getSortedLabels(inputs), 'displayName'
      expectedOut = ['important', 'inbox', 'receipts', 'social', 'work']
      expect(actualOut).toEqual expectedOut
