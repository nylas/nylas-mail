_ = require 'underscore-plus'
Contact = require '../../../src/flux/models/contact'
Message = require '../../../src/flux/models/message'
Thread = require '../../../src/flux/models/thread'
Tag = require '../../../src/flux/models/tag'
DatabaseStore = require '../../../src/flux/stores/database-store'
Main = require '../lib/main'

describe "UnreadNotifications", ->
  beforeEach ->
    Main.activate()

    @threadA = new Thread
      tags: [new Tag(id: 'inbox')]
    @threadB = new Thread
      tags: [new Tag(id: 'archive')]

    @msg1 = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Ben', email: 'ben@example.com')]
      subject: "Hello World"
      threadId: "A"
    @msg2 = new Message
      unread: true
      date: new Date()
      from: [new Contact(name: 'Mark', email: 'mark@example.com')]
      subject: "Hello World 2"
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
        expect(window.Notification).toHaveBeenCalled()
        expect(window.Notification.mostRecentCall.args).toEqual([ 'Ben', { body : 'Hello World', tag : 'unread-update' } ])

  it "should create a Notification if there is more than one unread message", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msg1, @msg2, @msgRead]})
      .then ->
        expect(window.Notification).toHaveBeenCalled()
        expect(window.Notification.mostRecentCall.args).toEqual([ '2 Unread Messages', { tag : 'unread-update' } ])

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

