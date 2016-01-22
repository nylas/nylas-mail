Utils = require "../../src/flux/models/utils"
Message = require "../../src/flux/models/message"
Contact = require "../../src/flux/models/contact"

evan = new Contact
  name: "Evan Morikawa"
  email: "evan@nylas.com"
ben = new Contact
  name: "Ben Gotow"
  email: "ben@nylas.com"
team = new Contact
  name: "Nylas Team"
  email: "team@nylas.com"
edgehill = new Contact
  name: "Edgehill"
  email: "edgehill@nylas.com"
noEmail = new Contact
  name: "Edgehill"
  email: null
me = new Contact
  name: TEST_ACCOUNT_NAME
  email: TEST_ACCOUNT_EMAIL
almost_me = new Contact
  name: TEST_ACCOUNT_NAME
  email: "tester+12345@nylas.com"

describe "Message", ->
  it "correctly aggregates participants", ->
    m1 = new Message
      to: []
      cc: null
      from: []
    expect(m1.participants().length).toBe 0

    m2 = new Message
      to: [evan]
      cc: []
      bcc: []
      from: [ben]
    expect(m2.participants().length).toBe 2

    m3 = new Message
      to: [evan]
      cc: [evan]
      bcc: [evan]
      from: [evan]
    expect(m3.participants().length).toBe 1

    m4 = new Message
      to: [evan]
      cc: [ben, team, noEmail]
      bcc: [team]
      from: [team]
    # because contact 4 has no email
    expect(m4.participants().length).toBe 3

    m5 = new Message
      to: [evan]
      cc: []
      bcc: [team]
      from: [ben]
    # because we exclude bccs
    expect(m5.participants().length).toBe 2

  describe "participant replies", ->
    cases = [
      # Basic cases
      {
        msg: new Message
          from: [evan]
          to: [me]
          cc: []
          bcc: []
        expected:
          to: [evan]
          cc: []
      }
      {
        msg: new Message
          from: [evan]
          to: [me]
          cc: [ben]
          bcc: []
        expected:
          to: [evan]
          cc: [ben]
      }
      {
        msg: new Message
          from: [evan]
          to: [ben]
          cc: [me]
          bcc: []
        expected:
          to: [evan]
          cc: [ben]
      }
      {
        msg: new Message
          from: [evan]
          to: [me]
          cc: [ben, team, evan]
          bcc: []
        expected:
          to: [evan]
          cc: [ben, team]
      }
      {
        msg: new Message
          from: [evan]
          to: [me, ben, evan, ben, ben, evan]
          cc: []
          bcc: []
        expected:
          to: [evan]
          cc: [ben]
      }
      {
        msg: new Message
          from: [evan]
          to: [me, ben]
          cc: [team, edgehill]
          bcc: [evan, me, ben]
        expected:
          to: [evan]
          cc: [ben, team, edgehill]
      }

      # From me (replying to a message I just sent)
      {
        msg: new Message
          from: [me]
          to: [me]
          cc: []
          bcc: []
        expected:
          to: [me]
          cc: []
      }
      {
        msg: new Message
          from: [me]
          to: [ben]
          cc: []
          bcc: []
        expected:
          to: [ben]
          cc: []
      }
      {
        msg: new Message
          from: [me]
          to: [ben, team, ben]
          cc: [edgehill]
          bcc: []
        expected:
          to: [ben, team]
          cc: [edgehill]
      }
      {
        msg: new Message
          from: [me]
          to: [ben, team, ben]
          cc: [edgehill]
          bcc: []
        expected:
          to: [ben, team]
          cc: [edgehill]
      }
      # From me in cases my similar alias is used
      {
        msg: new Message
          from: [me]
          to: [almost_me]
          cc: [ben]
          bcc: []
        expected:
          to: [almost_me]
          cc: [ben]
      }
      {
        msg: new Message
          from: [me]
          to: [me, almost_me, me]
          cc: [ben, almost_me, me, me, ben, ben]
          bcc: []
        expected:
          to: [me]
          cc: [ben]
      }
      {
        msg: new Message
          from: [almost_me]
          to: [me]
          cc: [ben]
          bcc: []
        expected:
          to: [me]
          cc: [ben]
      }
      {
        msg: new Message
          from: [almost_me]
          to: [almost_me]
          cc: [ben]
          bcc: []
        expected:
          to: [almost_me]
          cc: [ben]
      }

      # Cases when I'm on email lists
      {
        msg: new Message
          from: [evan]
          to: [team]
          cc: []
          bcc: []
        expected:
          to: [evan]
          cc: [team]
      }
      {
        msg: new Message
          from: [evan]
          to: [team]
          cc: [ben, edgehill]
          bcc: []
        expected:
          to: [evan]
          cc: [team, ben, edgehill]
      }
      {
        msg: new Message
          from: [evan]
          to: [team]
          cc: [me]
          bcc: []
        expected:
          to: [evan]
          cc: [team]
      }
      {
        msg: new Message
          from: [evan]
          to: [team, me]
          cc: [ben]
          bcc: []
        expected:
          to: [evan]
          cc: [team, ben]
      }

      # Cases when I'm bcc'd
      {
        msg: new Message
          from: [evan]
          to: []
          cc: []
          bcc: [me]
        expected:
          to: [evan]
          cc: []
      }
      {
        msg: new Message
          from: [evan]
          to: [ben]
          cc: []
          bcc: [me]
        expected:
          to: [evan]
          cc: [ben]
      }
      {
        msg: new Message
          from: [evan]
          to: [ben]
          cc: [team, edgehill]
          bcc: [me]
        expected:
          to: [evan]
          cc: [ben, team, edgehill]
      }

      # Cases my similar alias is used
      {
        msg: new Message
          from: [evan]
          to: [almost_me]
          cc: []
          bcc: []
        expected:
          to: [evan]
          cc: []
      }
      {
        msg: new Message
          from: [evan]
          to: [ben]
          cc: [almost_me]
          bcc: []
        expected:
          to: [evan]
          cc: [ben]
      }
      {
        msg: new Message
          from: [evan]
          to: [ben]
          cc: []
          bcc: [almost_me]
        expected:
          to: [evan]
          cc: [ben]
      }
    ]

    itString = (prefix, msg) ->
      return "#{prefix} from: #{msg.from.map( (c) -> c.email).join(', ')} | to: #{msg.to.map( (c) -> c.email).join(', ')} | cc: #{msg.cc.map( (c) -> c.email).join(', ')} | bcc: #{msg.bcc.map( (c) -> c.email).join(', ')}"

    it "thinks me and almost_me are equivalent", ->
      expect(Utils.emailIsEquivalent(me.email, almost_me.email)).toBe true
      expect(Utils.emailIsEquivalent(ben.email, me.email)).toBe false

    cases.forEach ({msg, expected}) ->
      it itString("Reply All:", msg), ->
        expect(msg.participantsForReplyAll()).toEqual expected

      it itString("Reply:", msg), ->
        {to, cc} = msg.participantsForReply()
        expect(to).toEqual expected.to
        expect(cc).toEqual []

  describe "participantsForReplyAll", ->
