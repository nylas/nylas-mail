Contact = require "../../src/flux/models/contact"
AccountStore = require "../../src/flux/stores/account-store"
Account = require "../../src/flux/models/account"

contact_1 =
  name: "Evan Morikawa"
  email: "evan@nylas.com"

describe "Contact", ->

  it "can be built via the constructor", ->
    c1 = new Contact contact_1
    expect(c1.name).toBe "Evan Morikawa"
    expect(c1.email).toBe "evan@nylas.com"

  it "accepts a JSON response", ->
    c1 = (new Contact).fromJSON(contact_1)
    expect(c1.name).toBe "Evan Morikawa"
    expect(c1.email).toBe "evan@nylas.com"

  it "correctly parses first and last names", ->
    c1 = new Contact {name: "Evan Morikawa"}
    expect(c1.firstName()).toBe "Evan"
    expect(c1.lastName()).toBe "Morikawa"

    c2 = new Contact {name: "evan takashi morikawa"}
    expect(c2.firstName()).toBe "Evan"
    expect(c2.lastName()).toBe "Takashi Morikawa"

    c3 = new Contact {name: "evan foo last-name"}
    expect(c3.firstName()).toBe "Evan"
    expect(c3.lastName()).toBe "Foo Last-Name"

    c4 = new Contact {name: "Prince"}
    expect(c4.firstName()).toBe "Prince"
    expect(c4.lastName()).toBe ""

    c5 = new Contact {name: "Mr. Evan Morikawa"}
    expect(c5.firstName()).toBe "Evan"
    expect(c5.lastName()).toBe "Morikawa"

    c6 = new Contact {name: "Mr Evan morikawa"}
    expect(c6.firstName()).toBe "Evan"
    expect(c6.lastName()).toBe "Morikawa"

    c7 = new Contact {name: "Dr. No"}
    expect(c7.firstName()).toBe "No"
    expect(c7.lastName()).toBe ""

    c8 = new Contact {name: "mr"}
    expect(c8.firstName()).toBe "Mr"
    expect(c8.lastName()).toBe ""

  it "properly parses Mike Kaylor via LinkedIn", ->
    c8 = new Contact {name: "Mike Kaylor via LinkedIn"}
    expect(c8.firstName()).toBe "Mike"
    expect(c8.lastName()).toBe "Kaylor"
    c8 = new Contact {name: "Mike Kaylor VIA LinkedIn"}
    expect(c8.firstName()).toBe "Mike"
    expect(c8.lastName()).toBe "Kaylor"
    c8 = new Contact {name: "Mike Viator"}
    expect(c8.firstName()).toBe "Mike"
    expect(c8.lastName()).toBe "Viator"
    c8 = new Contact {name: "Olivia Pope"}
    expect(c8.firstName()).toBe "Olivia"
    expect(c8.lastName()).toBe "Pope"

  it "properly parses evan (Evan Morikawa)", ->
    c8 = new Contact {name: "evan (Evan Morikawa)"}
    expect(c8.firstName()).toBe "Evan"
    expect(c8.lastName()).toBe "Morikawa"

  it "falls back to the first component of the email if name isn't present", ->
    c1 = new Contact {name: " Evan Morikawa ", email: "evan@nylas.com"}
    expect(c1.displayName()).toBe "Evan Morikawa"
    expect(c1.displayFirstName()).toBe "Evan"
    expect(c1.displayLastName()).toBe "Morikawa"

    c2 = new Contact {name: "", email: "evan@nylas.com"}
    expect(c2.displayName()).toBe "Evan"
    expect(c2.displayFirstName()).toBe "Evan"
    expect(c2.displayLastName()).toBe ""

    c3 = new Contact {name: "", email: ""}
    expect(c3.displayName()).toBe ""
    expect(c3.displayFirstName()).toBe ""
    expect(c3.displayLastName()).toBe ""


  it "properly parses names with @", ->
    c1 = new Contact {name: "nyl@s"}
    expect(c1.firstName()).toBe "Nyl@s"
    expect(c1.lastName()).toBe ""

    c1 = new Contact {name: "nyl@s@n1"}
    expect(c1.firstName()).toBe "Nyl@s@n1"
    expect(c1.lastName()).toBe ""

    c2 = new Contact {name: "nyl@s nyl@s"}
    expect(c2.firstName()).toBe "Nyl@s"
    expect(c2.lastName()).toBe "Nyl@s"

    c3 = new Contact {name: "nyl@s 2000"}
    expect(c3.firstName()).toBe "Nyl@s"
    expect(c3.lastName()).toBe "2000"

    c4 = new Contact {name: " Ev@n Morikawa ", email: "evan@nylas.com"}
    expect(c4.displayName()).toBe "Ev@n Morikawa"
    expect(c4.displayFirstName()).toBe "Ev@n"
    expect(c4.displayLastName()).toBe "Morikawa"

    c5 = new Contact {name: "ev@n (Evan Morik@wa)"}
    expect(c5.firstName()).toBe "Evan"
    expect(c5.lastName()).toBe "Morik@wa"

    c6 = new Contact {name: "ev@nylas.com", email: "ev@nylas.com"}
    expect(c6.firstName()).toBe "Ev@nylas.com"
    expect(c6.lastName()).toBe ""

    c7 = new Contact {name: "evan@nylas.com"}
    expect(c7.firstName()).toBe "Evan@nylas.com"
    expect(c7.lastName()).toBe ""

    c8 = new Contact {name: "Mike K@ylor via L@nkedIn"}
    expect(c8.firstName()).toBe "Mike"
    expect(c8.lastName()).toBe "K@ylor"

  it "should properly return `You` as the display name for the current user", ->
    c1 = new Contact {name: " Test Monkey", email: AccountStore.current().emailAddress}
    expect(c1.displayName()).toBe "You"
    expect(c1.displayFirstName()).toBe "You"
    expect(c1.displayLastName()).toBe ""

  describe "isMe", ->
    it "returns true if the contact name matches the account email address", ->
      c1 = new Contact {email: AccountStore.current().emailAddress}
      expect(c1.isMe()).toBe(true)
      c1 = new Contact {email: 'ben@nylas.com'}
      expect(c1.isMe()).toBe(false)

    it "is case insensitive", ->
      c1 = new Contact {email: AccountStore.current().emailAddress.toUpperCase()}
      expect(c1.isMe()).toBe(true)

    it "also matches any aliases you've created", ->
      jasmine.unspy(AccountStore, 'current')
      spyOn(AccountStore, 'current').andCallFake ->
        new Account
          provider: "gmail"
          aliases: ["Ben Other <ben22@nylas.com>"]
          emailAddress: 'ben@nylas.com'

      c1 = new Contact {email: 'ben22@nylas.com'}
      expect(c1.isMe()).toBe(true)
      c1 = new Contact {email: 'ben23@nylas.com'}
      expect(c1.isMe()).toBe(false)
