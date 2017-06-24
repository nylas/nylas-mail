Message = require('../../src/flux/models/message').default
Thread = require('../../src/flux/models/thread').default
Category = require('../../src/flux/models/category').default
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

  describe "inAllMail", ->
    describe "when the thread categoriesType is 'folders'", ->
      it "should return true", ->
        thread = new Thread(categoriesType: 'folders', categories: [new Category(name: 'inbox')])
        expect(thread.inAllMail).toBe(true)

        # Unlike Gmail, this means half the thread is in trash and half is in sent.
        # It should still appear in results for "Sent"
        thread = new Thread(categoriesType: 'folders', categories: [new Category(name: 'sent'), new Category(name: 'trash')])
        expect(thread.inAllMail).toBe(true)

    describe "when the thread categoriesType is 'labels'", ->
      it "should return true if the thread has an all category", ->
        thread = new Thread(categoriesType: 'labels', categories: [new Category(name: 'all')])
        expect(thread.inAllMail).toBe(true)

        # thread is half in spam
        thread = new Thread(categoriesType: 'labels', categories: [new Category(name: 'all'), new Category(name: 'inbox'), new Category(name: 'spam')])
        expect(thread.inAllMail).toBe(true)

      it "should return false if the thread has the spam category and no all mail", ->
        thread = new Thread(categoriesType: 'labels', categories: [new Category(name: 'sent'), new Category(name: 'spam')])
        expect(thread.inAllMail).toBe(false)

      it "should return false if the thread has the trash category and no all mail", ->
        thread = new Thread(categoriesType: 'labels', categories: [new Category(name: 'sent'), new Category(name: 'trash')])
        expect(thread.inAllMail).toBe(false)

      it "should return true if the thread has none of the above (assume all mail)", ->
        thread = new Thread(categoriesType: 'labels', categories: [new Category(name: 'inbox')])
        expect(thread.inAllMail).toBe(true)

  describe 'sortedCategories', ->
    sortedForCategoryNames = (inputs) ->
      categories = _.map inputs, (i) ->
        new Category(name: i, displayName: i)
      thread = new Thread(categories: categories)
      return thread.sortedCategories()

    it "puts 'important' label first, if it's present", ->
      inputs = ['alphabetically before important', 'important']
      actualOut = sortedForCategoryNames inputs
      expect(actualOut[0].displayName).toBe 'important'

    it "ignores 'important' label if not present", ->
      inputs = ['not important']
      actualOut = sortedForCategoryNames inputs
      expect(actualOut.length).toBe 1
      expect(actualOut[0].displayName).toBe 'not important'

    it "doesn't display 'all', 'archive', or 'drafts'", ->
      inputs = ['all', 'archive', 'drafts']
      actualOut = sortedForCategoryNames inputs
      expect(actualOut.length).toBe 0

    it "displays standard category names which aren't hidden next, if they're present", ->
      inputs = ['inbox', 'important', 'social']
      actualOut = _.pluck sortedForCategoryNames(inputs), 'displayName'
      expectedOut = ['important', 'inbox', 'social']
      expect(actualOut).toEqual expectedOut

    it "ignores standard category names if they aren't present", ->
      inputs = ['social', 'work', 'important']
      actualOut = _.pluck sortedForCategoryNames(inputs), 'displayName'
      expectedOut = ['important', 'social', 'work']
      expect(actualOut).toEqual expectedOut

    it "puts user-added categories at the end", ->
      inputs = ['food', 'inbox']
      actualOut = _.pluck sortedForCategoryNames(inputs), 'displayName'
      expectedOut = ['inbox', 'food']
      expect(actualOut).toEqual expectedOut

    it "sorts user-added categories by displayName", ->
      inputs = ['work', 'social', 'receipts', 'important', 'inbox']
      actualOut = _.pluck sortedForCategoryNames(inputs), 'displayName'
      expectedOut = ['important', 'inbox', 'receipts', 'social', 'work']
      expect(actualOut).toEqual expectedOut
