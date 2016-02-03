React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

_ = require 'underscore'
{AccountStore, Thread, Contact, Message} = require 'nylas-exports'
ThreadListParticipants = require '../lib/thread-list-participants'

describe "ThreadListParticipants", ->

  beforeEach ->
    @account = AccountStore.accounts()[0]

  it "renders into the document", ->
    @participants = ReactTestUtils.renderIntoDocument(
      <ThreadListParticipants thread={new Thread}/>
    )
    expect(ReactTestUtils.isCompositeComponentWithType(@participants, ThreadListParticipants)).toBe true

  it "renders unread contacts with .unread-true", ->
    ben = new Contact(email: 'ben@nylas.com', name: 'ben')
    ben.unread = true
    thread = new Thread()
    thread.metadata = [new Message(from: [ben], unread:true)]

    @participants = ReactTestUtils.renderIntoDocument(
      <ThreadListParticipants thread={thread}/>
    )
    unread = ReactTestUtils.scryRenderedDOMComponentsWithClass(@participants, 'unread-true')
    expect(unread.length).toBe(1)

  describe "getTokens", ->
    beforeEach ->
      @ben = new Contact(email: 'ben@nylas.com', name: 'ben')
      @evan = new Contact(email: 'evan@nylas.com', name: 'evan')
      @evanAgain = new Contact(email: 'evan@nylas.com', name: 'evan')
      @michael = new Contact(email: 'michael@nylas.com', name: 'michael')
      @kavya = new Contact(email: 'kavya@nylas.com', name: 'kavya')
      @phab1 = new Contact(email: 'no-reply@phab.nylas.com', name: 'Ben')
      @phab2 = new Contact(email: 'no-reply@phab.nylas.com', name: 'MG')

    describe "when thread.messages is available", ->
      it "correctly produces items for display in a wide range of scenarios", ->
        scenarios = [{
          name: 'single read email'
          in: [
            new Message(unread: false, from: [@ben]),
          ]
          out: [{contact: @ben, unread: false}]
        },{
          name: 'single read email and draft'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(from: [@ben], draft: true),
          ]
          out: [{contact: @ben, unread: false}]
        },{
          name: 'single unread email'
          in: [
            new Message(unread: true, from: [@evan]),
          ]
          out: [{contact: @evan, unread: true}]
        },{
          name: 'single unread response'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
          ]
          out: [{contact: @ben, unread: false}, {contact: @evan, unread: true}]
        },{
          name: 'two unread responses'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@kavya]),
          ]
          out: [{contact: @ben, unread: false},
                {contact: @evan, unread: true},
                {contact: @kavya, unread: true}]
        },{
          name: 'two unread responses (repeated participants)'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@evanAgain]),
          ]
          out: [{contact: @ben, unread: false}, {contact: @evan, unread: true}]
        },{
          name: 'three unread responses (repeated participants)'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@michael]),
            new Message(unread: true, from: [@evanAgain]),
          ]
          out: [{contact: @ben, unread: false},
                {spacer: true},
                {contact: @michael, unread: true},
                {contact: @evanAgain, unread: true}]
        },{
          name: 'three unread responses'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evan]),
            new Message(unread: true, from: [@michael]),
            new Message(unread: true, from: [@kavya]),
          ]
          out: [{contact: @ben, unread: false},
                {spacer: true},
                {contact: @michael, unread: true},
                {contact: @kavya, unread: true}]
        },{
          name: 'ends with two emails from the same person, second one is unread'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: false, from: [@evan]),
            new Message(unread: false, from: [@kavya]),
            new Message(unread: true, from: [@kavya]),
          ]
          out: [{contact: @ben, unread: false},
                {contact: @evan, unread: false},
                {contact: @kavya, unread: true}]
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
          out: [{contact: @ben, unread: false},
                {spacer: true},
                {contact: @michael, unread: true},
                {contact: @evanAgain, unread: true}]
        },{
          name: 'single unread responses to long thread'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: false, from: [@evan]),
            new Message(unread: false, from: [@michael]),
            new Message(unread: false, from: [@ben]),
            new Message(unread: true, from: [@evanAgain]),
          ]
          out: [{contact: @ben, unread: false},
                {spacer: true},
                {contact: @ben, unread: false},
                {contact: @evanAgain, unread: true}]
        },{
          name: 'long read thread'
          in: [
            new Message(unread: false, from: [@ben]),
            new Message(unread: false, from: [@evan]),
            new Message(unread: false, from: [@michael]),
            new Message(unread: false, from: [@ben]),
          ]
          out: [{contact: @ben, unread: false},
                {spacer: true},
                {contact: @michael, unread: false},
                {contact: @ben, unread: false}]
        },{
          name: 'thread with different participants with the same email address'
          in: [
            new Message(unread: false, from: [@phab1]),
            new Message(unread: false, from: [@phab2])
          ]
          out: [{contact: @phab1, unread: false},
                {contact: @phab2, unread: false}]
        }]

        for scenario in scenarios
          thread = new Thread()
          thread.metadata = scenario.in
          participants = ReactTestUtils.renderIntoDocument(
            <ThreadListParticipants thread={thread}/>
          )

          expect(participants.getTokens()).toEqual(scenario.out)

          # Slightly misuse jasmine to get the output we want to show
          if (!_.isEqual(participants.getTokens(), scenario.out))
            expect(scenario.name).toBe('correct')

    describe "when getTokens() called and current user is only sender", ->
      beforeEach ->
        @me = @account.me()
        @ben = new Contact(email: 'ben@nylas.com', name: 'ben')
        @evan = new Contact(email: 'evan@nylas.com', name: 'evan')
        @evanCapitalized = new Contact(email: 'EVAN@nylas.com', name: 'evan')
        @michael = new Contact(email: 'michael@nylas.com', name: 'michael')
        @kavya = new Contact(email: 'kavya@nylas.com', name: 'kavya')

      getTokens = (threadMetadata) ->
        thread = new Thread()
        thread.metadata = threadMetadata
        participants = ReactTestUtils.renderIntoDocument(
          <ThreadListParticipants thread={thread}/>
        )
        participants.getTokens()

      it "shows only recipients for emails sent from me to different recipients", ->
        input = [new Message(unread: false, from: [@me], to: [@ben])
                 new Message(unread: false, from: [@me], to: [@evan])
                 new Message(unread: false, from: [@me], to: [@ben])]
        actualOut = getTokens(input)
        expectedOut = [{contact: @ben, unread: false}
                       {contact: @evan, unread: false}
                       {contact: @ben, unread: false}]
        expect(actualOut).toEqual expectedOut

      it "is case insensitive", ->
        input = [new Message(unread: false, from: [@me], to: [@evan])
                 new Message(unread: false, from: [@me], to: [@evanCapitalized])]
        actualOut = getTokens(input)
        expectedOut = [{contact: @evan, unread: false}]
        expect(actualOut).toEqual expectedOut

      it "shows only first, spacer, second to last, and last recipients if recipients count > 3", ->
        input = [new Message(unread: false, from: [@me], to: [@ben])
                 new Message(unread: false, from: [@me], to: [@evan])
                 new Message(unread: false, from: [@me], to: [@michael])
                 new Message(unread: false, from: [@me], to: [@kavya])]
        actualOut = getTokens(input)
        expectedOut = [{contact: @ben, unread: false}
                       {spacer: true}
                       {contact: @michael, unread: false}
                       {contact: @kavya, unread: false}]
        expect(actualOut).toEqual expectedOut

      it "shows correct recipients even if only one email", ->
        input = [new Message(unread: false, from: [@me], to: [@ben, @evan, @michael, @kavya])]
        actualOut = getTokens(input)
        expectedOut = [{contact: @ben, unread: false}
                       {spacer: true}
                       {contact: @michael, unread: false}
                       {contact: @kavya, unread: false}]
        expect(actualOut).toEqual expectedOut

      it "shows only one recipient if the sender only sent to one recipient", ->
        input = [new Message(unread: false, from: [@me], to: [@evan])
                 new Message(unread: false, from: [@me], to: [@evan])
                 new Message(unread: false, from: [@me], to: [@evan])
                 new Message(unread: false, from: [@me], to: [@evan])]
        actualOut = getTokens(input)
        expectedOut = [{contact: @evan, unread: false}]
        expect(actualOut).toEqual expectedOut

      it "shows only the recipient for one sent email", ->
        input = [new Message(unread: false, from: [@me], to: [@evan])]
        actualOut = getTokens(input)
        expectedOut = [{contact: @evan, unread: false}]
        expect(actualOut).toEqual expectedOut

      it "shows unread email as well", ->
        input = [new Message(unread: false, from: [@me], to: [@evan])
                 new Message(unread: false, from: [@me], to: [@ben])
                 new Message(unread: true, from: [@me], to: [@kavya])
                 new Message(unread: true, from: [@me], to: [@michael])]
        actualOut = getTokens(input)
        expectedOut = [{contact: @evan, unread: false},
                       {spacer: true},
                       {contact: @kavya, unread: true},
                       {contact: @michael, unread: true}]
        expect(actualOut).toEqual expectedOut

    describe "when thread.messages is not available", ->
      it "correctly produces items for display in a wide range of scenarios", ->
        me = @account.me()
        scenarios = [{
          name: 'one participant'
          in: [@ben]
          out: [{contact: @ben, unread: false}]
        },{
          name: 'one participant (me)'
          in: [me]
          out: [{contact: me, unread: false}]
        },{
          name: 'two participants'
          in: [@evan, @ben]
          out: [{contact: @evan, unread: false}, {contact: @ben, unread: false}]
        },{
          name: 'two participants (me)'
          in: [@ben, me]
          out: [{contact: @ben, unread: false}]
        },{
          name: 'lots of participants'
          in: [@ben, @evan, @michael, @kavya]
          out: [{contact: @ben, unread: false},
                {spacer: true},
                {contact: @michael, unread: false},
                {contact: @kavya, unread: false}]
        }]

        for scenario in scenarios
          thread = new Thread()
          thread.participants = scenario.in
          participants = ReactTestUtils.renderIntoDocument(
            <ThreadListParticipants thread={thread}/>
          )

          expect(participants.getTokens()).toEqual(scenario.out)

          # Slightly misuse jasmine to get the output we want to show
          if (!_.isEqual(participants.getTokens(), scenario.out))
            expect(scenario.name).toBe('correct')
