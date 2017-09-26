_ = require 'underscore'

{Event,
 Actions,
 APIError,
 EventRSVPTask,
 DatabaseStore,
 DatabaseWriter,
 AccountStore} = require 'mailspring-exports'

xdescribe "EventRSVPTask", ->
  beforeEach ->
    spyOn(DatabaseStore, 'find').andCallFake => Promise.resolve(@event)
    spyOn(DatabaseWriter.prototype, 'persistModel').andCallFake -> Promise.resolve()
    @myName = "Ben Tester"
    @myEmail = "tester@nylas.com"
    @event = new Event
      id: '12233AEDF5'
      accountId: TEST_ACCOUNT_ID
      title: 'Meeting with Ben Bitdiddle'
      description: ''
      location: ''
      when:
        end_time: 1408123800
        start_time: 1408120200
      start: 1408120200
      end: 1408123800
      participants: [
        {"name": "Ben Bitdiddle",
        "email": "ben@bitdiddle.com",
        "status": "yes"},
        {"name": @myName,
        "email": @myEmail,
        "status": 'noreply'}
      ]
    @task = new EventRSVPTask(@event, @myEmail, "no")

  describe "performLocal", ->
    it "should mark our status as no", ->
      @task.performLocal()
      advanceClock()
      expect(@event.participants[1].status).toBe "no"

    it "should trigger an action to persist the change", ->
      @task.performLocal()
      advanceClock()
      expect(DatabaseWriter.prototype.persistModel).toHaveBeenCalled()

