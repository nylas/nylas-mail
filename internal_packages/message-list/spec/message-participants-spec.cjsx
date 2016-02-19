_ = require 'underscore'
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
TestUtils = React.addons.TestUtils
{Contact, Message, DOMUtils} = require "nylas-exports"
MessageParticipants = require "../lib/message-participants"

user_1 =
  name: "User One"
  email: "user1@nylas.com"
user_2 =
  name: "User Two"
  email: "user2@nylas.com"
user_3 =
  name: "User Three"
  email: "user3@nylas.com"
user_4 =
  name: "User Four"
  email: "user4@nylas.com"
user_5 =
  name: "User Five"
  email: "user5@nylas.com"

many_users = (new Contact({name: "User #{i}", email:"#{i}@app.com"}) for i in [0..100])

test_message = (new Message).fromJSON({
  "id"   : "111",
  "from" : [ user_1 ],
  "to"   : [ user_2 ],
  "cc"   : [ user_3, user_4 ],
  "bcc"  : [ user_5 ]
})

big_test_message = (new Message).fromJSON({
  "id"   : "222",
  "from" : [ user_1 ],
  "to"   : many_users
})

many_thread_users = [user_1].concat(many_users)

describe "MessageParticipants", ->
  describe "when collapsed", ->
    makeParticipants = (props) ->
      TestUtils.renderIntoDocument(
        <MessageParticipants {...props} />
      )

    it "renders into the document", ->
      participants = makeParticipants(to: test_message.to, cc: test_message.cc,
                                      from: test_message.from, message_participants: test_message.participants())
      expect(participants).toBeDefined()

    it "uses short names", ->
      actualOut = makeParticipants(to: test_message.to)
      to = ReactTestUtils.findRenderedDOMComponentWithClass(actualOut, "to-contact")
      expect(React.findDOMNode(to).innerHTML).toBe "User"

    it "doesn't render any To nodes if To array is empty", ->
      actualOut = makeParticipants(to: [])
      findToField = ->
        ReactTestUtils.findRenderedDOMComponentWithClass(actualOut, "to-contact")
      expect(findToField).toThrow()

    it "doesn't render any Cc nodes if Cc array is empty", ->
      actualOut = makeParticipants(cc: [])
      findCcField = ->
        ReactTestUtils.findRenderedDOMComponentWithClass(actualOut, "cc-contact")
      expect(findCcField).toThrow()

    it "doesn't render any Bcc nodes if Bcc array is empty", ->
      actualOut = makeParticipants(bcc: [])
      findBccField = ->
        ReactTestUtils.findRenderedDOMComponentWithClass(actualOut, "bcc-contact")
      expect(findBccField).toThrow()

  describe "when expanded", ->
    beforeEach ->
      @participants = TestUtils.renderIntoDocument(
        <MessageParticipants to={test_message.to}
                             cc={test_message.cc}
                             from={test_message.from}
                             isDetailed={true}
                             message_participants={test_message.participants()} />
      )

    it "renders into the document", ->
      participants = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, "expanded-participants")
      expect(participants).toBeDefined()

    it "uses full names", ->
      to = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, "to-contact")
      expect(React.findDOMNode(to).innerText.trim()).toEqual "User Two<user2@nylas.com>"


  # TODO: We no longer display "to everyone"
  #
  # it "determines the message is to everyone", ->
  #   p1 = TestUtils.renderIntoDocument(
  #     <MessageParticipants to={big_test_message.to}
  #                          cc={big_test_message.cc}
  #                          from={big_test_message.from}
  #                          message_participants={big_test_message.participants()} />
  #   )
  #   expect(p1._isToEveryone()).toBe true
  #
  # it "knows when the message isn't to everyone due to participant mismatch", ->
  #   p2 = TestUtils.renderIntoDocument(
  #     <MessageParticipants to={test_message.to}
  #                          cc={test_message.cc}
  #                          from={test_message.from}
  #                          message_participants={test_message.participants()} />
  #   )
  #   # this should be false because we don't count bccs
  #   expect(p2._isToEveryone()).toBe false
  #
  # it "knows when the message isn't to everyone due to participant size", ->
  #   p2 = TestUtils.renderIntoDocument(
  #     <MessageParticipants to={test_message.to}
  #                          cc={test_message.cc}
  #                          from={test_message.from}
  #                          message_participants={test_message.participants()} />
  #   )
  #   # this should be false because we don't count bccs
  #   expect(p2._isToEveryone()).toBe false
