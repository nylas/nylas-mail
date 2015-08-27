_ = require 'underscore'
fs = require 'fs'
Actions = require '../src/flux/actions'
NylasAPI = require '../src/flux/nylas-api'
Thread = require '../src/flux/models/thread'
DatabaseStore = require '../src/flux/stores/database-store'

describe "NylasAPI", ->
  describe "handleModel404", ->
    it "should unpersist the model from the cache that was requested", ->
      model = new Thread(id: 'threadidhere')
      spyOn(DatabaseStore, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(model)
      NylasAPI._handleModel404("/threads/#{model.id}")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, model.id)
      expect(DatabaseStore.unpersistModel).toHaveBeenCalledWith(model)

    it "should not do anything if the model is not in the cache", ->
      spyOn(DatabaseStore, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(null)
      NylasAPI._handleModel404("/threads/1234")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, '1234')
      expect(DatabaseStore.unpersistModel).not.toHaveBeenCalledWith()

    it "should not do anything bad if it doesn't recognize the class", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseStore, 'unpersistModel')
      waitsForPromise ->
        NylasAPI._handleModel404("/asdasdasd/1234")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseStore.unpersistModel).not.toHaveBeenCalled()

    it "should not do anything bad if the endpoint only has a single segment", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseStore, 'unpersistModel')
      waitsForPromise ->
        NylasAPI._handleModel404("/account")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseStore.unpersistModel).not.toHaveBeenCalled()

  describe "handle401", ->
    it "should post a notification", ->
      spyOn(Actions, 'postNotification')
      NylasAPI._handle401('/threads/1234')
      expect(Actions.postNotification).toHaveBeenCalled()
      expect(Actions.postNotification.mostRecentCall.args[0].message).toEqual("Nylas can no longer authenticate with your mail provider. You will not be able to send or receive mail. Please log out and sign in again.")

  # These specs are on hold because this function is changing very soon

  xdescribe "handleModelResponse", ->
    it "should reject if no JSON is provided", ->
    it "should resolve if an empty JSON array is provided", ->

    describe "if JSON contains the same object more than once", ->
      it "should warn", ->
      it "should omit duplicates", ->

    describe "if JSON contains objects which are of unknown types", ->
      it "should warn and resolve", ->

    describe "when the object type is `thread`", ->
      it "should check that models are acceptable", ->

    describe "when the object type is `draft`", ->
      it "should check that models are acceptable", ->

    it "should call persistModels to save all of the received objects", ->

    it "should resolve with the objects", ->
