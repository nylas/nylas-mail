NotificationsStore = require '../lib/notifications-store.coffee'
Notification = NotificationsStore.Notification
{Actions} = require 'inbox-exports'

describe 'Notification', ->

  it 'should assert that a message has been provided', ->
    expect( -> new Notification({})).toThrow()

  it 'should assert that a valid type has been provided', ->
    for type in ['info', 'success', 'error']
      expect( -> new Notification({type: type, message: 'bla'})).not.toThrow()
    expect( -> new Notification({type: 'extreme'})).toThrow()

  it 'should assert that any actions have ids and labels', ->
    expect( -> new Notification({type: 'info', message: '1', actions:[{id: 'a'}]})).toThrow()
    expect( -> new Notification({type: 'info', message: '2', actions:[{label: 'b'}]})).toThrow()
    expect( -> new Notification({type: 'info', message: '3', actions:[{id: 'a', label: 'b'}]})).not.toThrow()

  it 'should assign its own ID and creation time', ->
    @n = new Notification({type: 'info', message: 'A', actions:[{id: 'a', label: 'b'}]})
    expect(@n.id).toBeDefined()
    expect(@n.creation).toBeDefined()

  it 'should be valid at creation', ->
    @n = new Notification({type: 'info', message: 'A', actions:[{id: 'a', label: 'b'}]})
    expect(@n.valid()).toBe true

describe 'NotificationStore', ->
  beforeEach ->
    NotificationsStore._flush()

  it 'should have no notifications by default', ->
    expect(NotificationsStore.notifications().length).toEqual 0

  it 'should register a notification', ->
    message = "Hello"
    Actions.postNotification({type: 'info', message: message})
    n = NotificationsStore.notifications()[0]
    expect(n.message).toEqual(message)

  it 'should unregister on removeNotification', ->
    Actions.postNotification({type: 'info', message: 'hi'})
    n = NotificationsStore.notifications()[0]
    NotificationsStore._removeNotification(n)()
    expect(NotificationsStore.notifications().length).toEqual 0

  describe "with a few notifications", ->
    beforeEach ->
      Actions.postNotification({type: 'info', message: 'A', sticky: true})
      Actions.postNotification({type: 'info', message: 'B', sticky: false})
      Actions.postNotification({type: 'info', message: 'C'})
      Actions.postNotification({type: 'info', message: 'D', sticky: true})

    describe "stickyNotifications", ->
      it 'should return all of the notifications with the sticky flag, ordered by date DESC', ->
        messages = NotificationsStore.stickyNotifications().map (n) -> n.message
        expect(messages).toEqual(['D','A'])

    describe "notifications", ->
      it 'should return all of the notifications without the sticky flag, ordered by date DESC', ->
        messages = NotificationsStore.notifications().map (n) -> n.message
        expect(messages).toEqual(['C','B'])
