_ = require 'underscore'
Contact = require '../../../src/flux/models/contact'
Message = require '../../../src/flux/models/message'
Thread = require '../../../src/flux/models/thread'
Label = require '../../../src/flux/models/label'
CategoryStore = require '../../../src/flux/stores/category-store'
DatabaseStore = require '../../../src/flux/stores/database-store'
AccountStore = require '../../../src/flux/stores/account-store'
Main = require '../lib/main'

describe "UnreadNotifications", ->
  beforeEach ->
    Main.activate()

    inbox = new Label(id: "l1", name: "inbox", displayName: "Inbox")
    archive = new Label(id: "l2", name: "archive", displayName: "Archive")

    spyOn(CategoryStore, "getStandardCategory").andReturn inbox

    @threadA = new Thread
      labels: [inbox]
    @threadB = new Thread
      labels: [archive]

    @msg1 = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Ben', email: 'ben@example.com')]
      subject: "Hello World"
      threadId: "A"
    @msgNoSender = new Message
      unread: true
      date: new Date()
      from: []
      subject: "Hello World"
      threadId: "A"
    @msg2 = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Mark', email: 'mark@example.com')]
      subject: "Hello World 2"
      threadId: "A"
    @msg3 = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Ben', email: 'ben@example.com')]
      subject: "Hello World"
      threadId: "A"
    @msg4 = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Ben', email: 'ben@example.com')]
      subject: "Hello World"
      threadId: "A"
    @msg5 = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Ben', email: 'ben@example.com')]
      subject: "Hello World"
      threadId: "A"
    @msgUnreadButArchived = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Mark', email: 'mark@example.com')]
      subject: "Hello World 2"
      threadId: "B"
    @msgRead = new Message
      unread: false
      date: new Date()
      from: [new Contact(name: 'Mark', email: 'mark@example.com')]
      subject: "Hello World Read Already"
      threadId: "A"
    @msgOld = new Message
      unread: true
      date: new Date(2000,1,1)
      from: [new Contact(name: 'Mark', email: 'mark@example.com')]
      subject: "Hello World Old"
      threadId: "A"
    @msgFromMe = new Message
      unread: true
      date: new Date()
      from: [AccountStore.current().me()]
      subject: "A Sent Mail!"
      threadId: "A"

    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      return Promise.resolve(@threadA) if id is 'A'
      return Promise.resolve(@threadB) if id is 'B'
      return Promise.resolve(null)

    spyOn(window, 'Notification').andCallFake ->
    spyOn(Promise, 'props').andCallFake (dict) ->
      dictOut = {}
      for key, val of dict
        if val.value?
          dictOut[key] = val.value()
        else
          dictOut[key] = val
      Promise.resolve(dictOut)

  afterEach ->
    Main.deactivate()

  it "should create a Notification if there is one unread message", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgRead, @msg1]})
      .then ->
        advanceClock(2000)
        expect(window.Notification).toHaveBeenCalled()
        expect(window.Notification.mostRecentCall.args).toEqual([ 'Ben', { body : 'Hello World', tag : 'unread-update' } ])

  it "should create multiple Notifications if there is more than one but less than five unread messages", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msg1, @msg2, @msg3]})
      .then ->
        #Need to call advance clock twice because we call setTimeout twice
        advanceClock(2000)
        advanceClock(2000)
        expect(window.Notification.callCount).toEqual(3)

  it "should create a Notification if there are five or more unread messages", ->
    waitsForPromise =>
      Main._onNewMailReceived({
        message: [@msg1, @msg2, @msg3, @msg4, @msg5]})
      .then ->
        advanceClock(2000)
        expect(window.Notification).toHaveBeenCalled()
        expect(window.Notification.mostRecentCall.args).toEqual([ '5 Unread Messages', { tag : 'unread-update' } ])

  it "should create a Notification correctly, even if new mail has no sender", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgNoSender]})
      .then ->
        expect(window.Notification).toHaveBeenCalled()
        expect(window.Notification.mostRecentCall.args).toEqual([ 'Unknown', { body : 'Hello World', tag : 'unread-update' } ])

  it "should not create a Notification if there are no new messages", ->
    waitsForPromise ->
      Main._onNewMailReceived({message: []})
      .then ->
        expect(window.Notification).not.toHaveBeenCalled()

    waitsForPromise ->
      Main._onNewMailReceived({})
      .then ->
        expect(window.Notification).not.toHaveBeenCalled()

  it "should not notify about unread messages that are outside the inbox", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgUnreadButArchived, @msg1]})
      .then ->
        expect(window.Notification).toHaveBeenCalled()
        expect(window.Notification.mostRecentCall.args).toEqual([ 'Ben', { body : 'Hello World', tag : 'unread-update' } ])

  it "should not create a Notification if the new messages are not unread", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgRead]})
      .then ->
        expect(window.Notification).not.toHaveBeenCalled()

  it "should not create a Notification if the new messages are actually old ones", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgOld]})
      .then ->
        expect(window.Notification).not.toHaveBeenCalled()

  it "should not create a Notification if the new message is one I sent", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgFromMe]})
      .then ->
        expect(window.Notification).not.toHaveBeenCalled()

