_ = require 'underscore'
Contact = require '../../../src/flux/models/contact'
Message = require '../../../src/flux/models/message'
Thread = require '../../../src/flux/models/thread'
Category = require '../../../src/flux/models/category'
CategoryStore = require '../../../src/flux/stores/category-store'
DatabaseStore = require '../../../src/flux/stores/database-store'
AccountStore = require '../../../src/flux/stores/account-store'
SoundRegistry = require '../../../src/sound-registry'
NativeNotifications = require '../../../src/native-notifications'
Main = require '../lib/main'

describe "UnreadNotifications", ->
  beforeEach ->
    Main.activate()

    inbox = new Category(id: "l1", name: "inbox", displayName: "Inbox")
    archive = new Category(id: "l2", name: "archive", displayName: "Archive")

    spyOn(CategoryStore, "getStandardCategory").andReturn inbox

    account = AccountStore.accounts()[0]

    @threadA = new Thread
      categories: [inbox]
    @threadB = new Thread
      categories: [archive]

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
      from: [account.me()]
      subject: "A Sent Mail!"
      threadId: "A"

    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      return Promise.resolve(@threadA) if id is 'A'
      return Promise.resolve(@threadB) if id is 'B'
      return Promise.resolve(null)

    spyOn(NativeNotifications, 'displayNotification').andCallFake ->
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
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()
        options = NativeNotifications.displayNotification.mostRecentCall.args[0]
        delete options['onActivate']
        expect(options).toEqual({
          title: 'Ben',
          subtitle: 'Hello World',
          body: undefined,
          canReply: true,
          tag: 'unread-update'
        })

  it "should create multiple Notifications if there is more than one but less than five unread messages", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msg1, @msg2, @msg3]})
      .then ->
        #Need to call advance clock twice because we call setTimeout twice
        advanceClock(2000)
        advanceClock(2000)
        expect(NativeNotifications.displayNotification.callCount).toEqual(3)

  it "should create a Notification if there are five or more unread messages", ->
    waitsForPromise =>
      Main._onNewMailReceived({
        message: [@msg1, @msg2, @msg3, @msg4, @msg5]})
      .then ->
        advanceClock(2000)
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()
        expect(NativeNotifications.displayNotification.mostRecentCall.args).toEqual([{
          title: '5 Unread Messages',
          tag: 'unread-update'
        }])

  it "should create a Notification correctly, even if new mail has no sender", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgNoSender]})
      .then ->
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()

        options = NativeNotifications.displayNotification.mostRecentCall.args[0]
        delete options['onActivate']
        expect(options).toEqual({
          title: 'Unknown',
          subtitle: 'Hello World',
          body: undefined,
          canReply : true,
          tag: 'unread-update'
        })

  it "should not create a Notification if there are no new messages", ->
    waitsForPromise ->
      Main._onNewMailReceived({message: []})
      .then ->
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()

    waitsForPromise ->
      Main._onNewMailReceived({})
      .then ->
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()

  it "should not notify about unread messages that are outside the inbox", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgUnreadButArchived, @msg1]})
      .then ->
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()
        options = NativeNotifications.displayNotification.mostRecentCall.args[0]
        delete options['onActivate']
        expect(options).toEqual({
          title: 'Ben',
          subtitle: 'Hello World',
          body: undefined,
          canReply : true,
          tag: 'unread-update'
        })

  it "should not create a Notification if the new messages are not unread", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgRead]})
      .then ->
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()

  it "should not create a Notification if the new messages are actually old ones", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgOld]})
      .then ->
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()

  it "should not create a Notification if the new message is one I sent", ->
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msgFromMe]})
      .then ->
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()

  it "should play a sound when it gets new mail", ->
    spyOn(NylasEnv.config, "get").andCallFake (config) ->
      if config is "core.notifications.enabled" then return true
      if config is "core.notifications.sounds" then return true

    spyOn(SoundRegistry, "playSound")
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msg1]})
      .then ->
        expect(NylasEnv.config.get.calls[1].args[0]).toBe "core.notifications.sounds"
        expect(SoundRegistry.playSound).toHaveBeenCalledWith("new-mail")

  it "should not play a sound if the config is off", ->
    spyOn(NylasEnv.config, "get").andCallFake (config) ->
      if config is "core.notifications.enabled" then return true
      if config is "core.notifications.sounds" then return false
    spyOn(SoundRegistry, "playSound")
    waitsForPromise =>
      Main._onNewMailReceived({message: [@msg1]})
      .then ->
        expect(NylasEnv.config.get.calls[1].args[0]).toBe "core.notifications.sounds"
        expect(SoundRegistry.playSound).not.toHaveBeenCalled()

  describe "when the message has no matching thread", ->
    beforeEach ->
      @msgNoThread = new Message
        unread: true
        date: new Date()
        from: [new Contact(name: 'Ben', email: 'ben@example.com')]
        subject: "Hello World"
        threadId: "missing"

    it "should not create a Notification, since it cannot be determined whether the message is in the Inbox", ->
      waitsForPromise =>
        Main._onNewMailReceived({message: [@msgNoThread]})
        .then ->
          advanceClock(2000)
          expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()

    it "should call _onNewMessagesMissingThreads to try displaying a notification again in 10 seconds", ->
      waitsForPromise =>
        spyOn(Main, '_onNewMessagesMissingThreads')
        Main._onNewMailReceived({message: [@msgNoThread]})
        .then =>
          advanceClock(2000)
          expect(Main._onNewMessagesMissingThreads).toHaveBeenCalledWith([@msgNoThread])

  describe "_onNewMessagesMissingThreads", ->
    beforeEach ->
      @msgNoThread = new Message
        unread: true
        date: new Date()
        from: [new Contact(name: 'Ben', email: 'ben@example.com')]
        subject: "Hello World"
        threadId: "missing"
      spyOn(Main, '_onNewMailReceived')
      Main._onNewMessagesMissingThreads([@msgNoThread])
      advanceClock(2000)

    it "should wait 10 seconds and then re-query for threads", ->
      expect(DatabaseStore.find).not.toHaveBeenCalled()
      @msgNoThread.threadId = "A"
      advanceClock(10000)
      expect(DatabaseStore.find).toHaveBeenCalled()
      advanceClock()
      expect(Main._onNewMailReceived).toHaveBeenCalledWith({message: [@msgNoThread], thread: [@threadA]})

    it "should do nothing if the threads still can't be found", ->
      expect(DatabaseStore.find).not.toHaveBeenCalled()
      advanceClock(10000)
      expect(DatabaseStore.find).toHaveBeenCalled()
      advanceClock()
      expect(Main._onNewMailReceived).not.toHaveBeenCalled()
