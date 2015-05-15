Message = require "../../src/flux/models/message"

contact_1 =
  name: "Contact One"
  email: "contact1@nylas.com"
contact_2 =
  name: "Contact Two"
  email: "contact2@nylas.com"
contact_3 =
  name: ""
  email: "contact3@nylas.com"
contact_4 =
  name: "Contact Four"
  email: ""

describe "Message", ->
  it "correctly aggregates participants", ->
    m1 = new Message
      to: []
      cc: null
      from: []
    expect(m1.participants().length).toBe 0

    m2 = new Message
      to: [contact_1]
      cc: []
      bcc: []
      from: [contact_2]
    expect(m2.participants().length).toBe 2

    m3 = new Message
      to: [contact_1]
      cc: [contact_1]
      bcc: [contact_1]
      from: [contact_1]
    expect(m3.participants().length).toBe 1

    m4 = new Message
      to: [contact_1]
      cc: [contact_2, contact_3, contact_4]
      bcc: [contact_3]
      from: [contact_3]
    # because contact 4 has no email
    expect(m4.participants().length).toBe 3

    m5 = new Message
      to: [contact_1]
      cc: []
      bcc: [contact_3]
      from: [contact_2]
    # because we exclude bccs
    expect(m5.participants().length).toBe 2
