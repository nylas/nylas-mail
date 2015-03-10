_ = require 'underscore-plus'
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
TestUtils = React.addons.TestUtils
{Contact, Message} = require "inbox-exports"
MessageParticipants = require "../lib/message-participants.cjsx"

user_1 =
  name: "User One"
  email: "user1@nilas.com"
user_2 =
  name: "User Two"
  email: "user2@nilas.com"
user_3 =
  name: "User Three"
  email: "user3@nilas.com"
user_4 =
  name: "User Four"
  email: "user4@nilas.com"
user_5 =
  name: "User Five"
  email: "user5@nilas.com"

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

thread_participants = [
  (new Contact(user_1)),
  (new Contact(user_2)),
  (new Contact(user_3)),
  (new Contact(user_4))
]

thread2_participants = [
  (new Contact(user_1)),
  (new Contact(user_2)),
  (new Contact(user_3)),
  (new Contact(user_4)),
  (new Contact(user_5))
]

describe "MessageParticipants", ->
  describe "when collapsed", ->
    beforeEach ->
      @participants = TestUtils.renderIntoDocument(
        <MessageParticipants to={test_message.to}
                             cc={test_message.cc}
                             from={test_message.from}
                             thread_participants={many_thread_users}
                             message_participants={test_message.participants()} />
      )

    it "renders into the document", ->
      participants = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, "collapsed-participants")
      expect(participants).toBeDefined()

    it "uses short names", ->
      to = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, "to-contact")
      expect(to.getDOMNode().innerHTML).toBe "User"

  describe "when expanded", ->
    beforeEach ->
      @participants = TestUtils.renderIntoDocument(
        <MessageParticipants to={test_message.to}
                             cc={test_message.cc}
                             from={test_message.from}
                             thread_participants={many_thread_users}
                             isDetailed={true}
                             message_participants={test_message.participants()} />
      )

    it "renders into the document", ->
      participants = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, "expanded-participants")
      expect(participants).toBeDefined()

    it "uses full names", ->
      to = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, "to-contact")
      expect(to.getDOMNode().innerText.trim()).toEqual "User Two <user2@nilas.com>"


  # TODO: We no longer display "to everyone"
  #
  # it "determines the message is to everyone", ->
  #   p1 = TestUtils.renderIntoDocument(
  #     <MessageParticipants to={big_test_message.to}
  #                          cc={big_test_message.cc}
  #                          from={big_test_message.from}
  #                          thread_participants={many_thread_users}
  #                          message_participants={big_test_message.participants()} />
  #   )
  #   expect(p1._isToEveryone()).toBe true
  #
  # it "knows when the message isn't to everyone due to participant mismatch", ->
  #   p2 = TestUtils.renderIntoDocument(
  #     <MessageParticipants to={test_message.to}
  #                          cc={test_message.cc}
  #                          from={test_message.from}
  #                          thread_participants={thread2_participants}
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
  #                          thread_participants={thread_participants}
  #                          message_participants={test_message.participants()} />
  #   )
  #   # this should be false because we don't count bccs
  #   expect(p2._isToEveryone()).toBe false
