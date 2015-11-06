Message = require '../../src/flux/models/message'
Thread = require '../../src/flux/models/thread'
Label = require '../../src/flux/models/label'
{Utils} = require 'nylas-exports'
_ = require 'underscore'

describe 'Thread', ->

  describe 'serialization performance', ->
    xit '1,000,000 iterations', ->
      iterations = 0
      json = '[{"client_id":"local-76c370af-65de","server_id":"f0vkowp7zxt7djue7ifylb940","object":"thread","account_id":"1r6w6qiq3sb0o9fiwin6v87dd","snippet":"http://itunestandc.tumblr.com/tagged/itunes-terms-and-conditions/chrono _______________________________________________ http://www.macgroup.com/mailman/listinfo/smartfriends-chat","subject":"iTunes Terms And Conditions as you\'ve never seen them before","unread":true,"starred":false,"version":1,"folders":[],"labels":[{"server_id":"8cf4fn20k9pjjhjawrv3xrxo0","name":"all","display_name":"All Mail","id":"8cf4fn20k9pjjhjawrv3xrxo0"},{"server_id":"f1lq8faw8vv06m67y8f3xdf84","name":"inbox","display_name":"Inbox","id":"f1lq8faw8vv06m67y8f3xdf84"}],"participants":[{"name":"Andrew Stadler","email":"stadler@gmail.com","thirdPartyData":{}},{"name":"Smart Friends™ Chat","email":"smartfriends-chat@macgroup.com","thirdPartyData":{}}],"has_attachments":false,"last_message_received_timestamp":1446600615,"id":"f0vkowp7zxt7djue7ifylb940"}]'
      start = Date.now()
      while iterations < 1000000
        if _.isString(json)
          data = JSON.parse(json)
        object = new Thread()
        object.fromJSON(data)
        object
        iterations += 1
      console.log((Date.now() - start) / 1000.0 + "ms per 1000")

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
