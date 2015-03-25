React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

_ = require 'underscore-plus'
{NamespaceStore, Thread, Contact, Message} = require 'inbox-exports'
ThreadListParticipants = require '../lib/thread-list-participants'

describe "ThreadListParticipants", ->

  it "renders into the document", ->
    @participants = ReactTestUtils.renderIntoDocument(
      <ThreadListParticipants thread={new Thread}/>
    )
    expect(ReactTestUtils.isCompositeComponentWithType(@participants, ThreadListParticipants)).toBe true

  it "renders unread contacts with .unread-true", ->
    ben = new Contact(email: 'ben@nilas.com', name: 'ben')
    ben.unread = true
    thread = new Thread()
    thread.messageMetadata = [new Message(from: [ben], unread:true)]

    @participants = ReactTestUtils.renderIntoDocument(
      <ThreadListParticipants thread={thread}/>
    )
    unread = ReactTestUtils.scryRenderedDOMComponentsWithClass(@participants, 'unread-true')
    expect(unread.length).toBe(1)

  describe "getParticipants", ->
    beforeEach ->
      @ben = new Contact(email: 'ben@nilas.com', name: 'ben')
      @evan = new Contact(email: 'evan@nilas.com', name: 'evan')
      @evanAgain = new Contact(email: 'evan@nilas.com', name: 'evan')
      @michael = new Contact(email: 'michael@nilas.com', name: 'michael')
      @kavya = new Contact(email: 'kavya@nilas.com', name: 'kavya')

    describe "when thread.messages is available", -> 
      it "correctly produces items for display in a wide range of scenarios", ->
        scenarios = [{
          name: 'single read email'
          in: [
            new Message(unread: false, from: [@ben]),
          ]
          out: [@ben]
        },{
          name: 'single unread email'
          in: [
            new Message(unread: true, from: [@evan]),
          ]
          out: [@evan]
        },{
          name: 'single unread response'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
          ]
          out: [@ben, @evan]
        },{
          name: 'two unread responses'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@kavya]),
          ]
          out: [@ben, @evan, @kavya]
        },{
          name: 'two unread responses (repeated participants)'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@evanAgain]),
          ]
          out: [@ben, @evan]
        },{
          name: 'three unread responses (repeated participants)'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@michael]),
            new Message(unread: true, from: [@evanAgain]),
          ]
          out: [@ben, {spacer: true}, @michael, @evanAgain]
        },{
          name: 'three unread responses'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@michael]),
            new Message(unread: true, from: [@kavya]),
          ]
          out: [@ben, {spacer: true}, @michael, @kavya]
        },{
          name: 'three unread responses to long thread'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: false, from: [@evan]),
            new Message(unread: false, from: [@michael]),
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evanAgain]),
            new Message(unread: true, from: [@michael]),
            new Message(unread: true, from: [@evanAgain]),
          ]
          out: [@ben, {spacer: true}, @michael, @evanAgain]
        },{
          name: 'single unread responses to long thread'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: false, from: [@evan]),
            new Message(unread: false, from: [@michael]),
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evanAgain]),
          ]
          out: [@ben, {spacer: true}, @ben, @evanAgain]
        },{
          name: 'long read thread'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: false, from: [@evan]),
            new Message(unread: false, from: [@michael]),
            new Message(unread: false, from: [@ben]),
          ]
          out: [@ben, {spacer: true}, @michael, @ben]
        }]

        for scenario in scenarios
          thread = new Thread()
          thread.messageMetadata = scenario.in
          participants = ReactTestUtils.renderIntoDocument(
            <ThreadListParticipants thread={thread}/>
          )

          expect(participants.getParticipants()).toEqual(scenario.out)

          # Slightly misuse jasmine to get the output we want to show
          if (!_.isEqual(participants.getParticipants(), scenario.out))
            expect(scenario.name).toBe('correct')


    describe "when thread.messages is not available", ->
      it "correctly produces items for display in a wide range of scenarios", ->
        me = NamespaceStore.current().me()
        scenarios = [{
          name: 'one participant'
          in: [@ben]
          out: [@ben]
        },{
          name: 'one participant (me)'
          in: [me]
          out: [me]
        },{
          name: 'two participants'
          in: [@evan, @ben]
          out: [@evan, @ben]
        },{
          name: 'two participants (me)'
          in: [@ben, me]
          out: [@ben]
        },{
          name: 'lots of participants'
          in: [@ben, @evan, @michael, @kavya]
          out: [@ben, {spacer: true}, @michael, @kavya]
        }]

        for scenario in scenarios
          thread = new Thread()
          thread.participants = scenario.in
          participants = ReactTestUtils.renderIntoDocument(
            <ThreadListParticipants thread={thread}/>
          )

          expect(participants.getParticipants()).toEqual(scenario.out)

          # Slightly misuse jasmine to get the output we want to show
          if (!_.isEqual(participants.getParticipants(), scenario.out))
            expect(scenario.name).toBe('correct')