import Utils from "../../src/flux/models/utils"
import Message from "../../src/flux/models/message"
import Contact from "../../src/flux/models/contact"

const evan = new Contact({
  name: "Evan Morikawa",
  email: "evan@nylas.com",
});
const ben = new Contact({
  name: "Ben Gotow",
  email: "ben@nylas.com",
});
const team = new Contact({
  name: "Nylas Team",
  email: "team@nylas.com",
});
const edgehill = new Contact({
  name: "Edgehill",
  email: "edgehill@nylas.com",
});
const noEmail = new Contact({
  name: "Edgehill",
  email: null,
});
const me = new Contact({
  name: TEST_ACCOUNT_NAME,
  email: TEST_ACCOUNT_EMAIL,
});
const almostMe = new Contact({
  name: TEST_ACCOUNT_NAME,
  email: "tester+12345@nylas.com",
});

fdescribe("Message", () => {
  describe("detecting empty bodies", () => {
    const cases = [
      {
        itMsg: "has plain br's and a signature",
        body: `
        <div class="contenteditable no-open-link-events" contenteditable="true" spellcheck="false"><br><br><signature>Sent from <a href="https://nylas.com/n1?ref=n1">Nylas N1</a>, the extensible, open source mail client.</signature></div>
      `,
        isEmpty: true,
      },
      {
        itMsg: "is an empty string",
        body: "",
        isEmpty: true,
      },
      {
        itMsg: "has plain text",
        body: "Hi",
        isEmpty: false,
      },
      {
        itMsg: "is null",
        body: null,
        isEmpty: true,
      },
      {
        itMsg: "has empty tags",
        body: `
        <div class="contenteditable no-open-link-events" contenteditable="true" spellcheck="false"><br><div><p>  </p></div>\n\n\n\n<br><signature>Sent from <a href="https://nylas.com/n1?ref=n1">Nylas N1</a>, the extensible, open source mail client.</signature></div>
      `,
        isEmpty: true,
      },
      {
        itMsg: "has nested characters",
        body: `
        <div class="contenteditable no-open-link-events" contenteditable="true" spellcheck="false"><br><div><p> 1</p></div>\n\n\n\n<br><signature>Sent from <a href="https://nylas.com/n1?ref=n1">Nylas N1</a>, the extensible, open source mail client.</signature></div>
      `,
        isEmpty: false,
      },
      {
        itMsg: "has just a signature",
        body: "<signature>Yo</signature>",
        isEmpty: true,
      },
      {
        itMsg: "has content after a signature",
        body: "<signature>Yo</signature>Yo",
        isEmpty: false,
      },
    ];
    cases.forEach(({itMsg, body, isEmpty}) => {
      it(itMsg, () => {
        const msg = new Message({body: body, pristine: false, draft: true});
        expect(msg.hasEmptyBody()).toBe(isEmpty);
      });
    });
  });

  it("correctly aggregates participants", () => {
    const m1 = new Message({
      to: [],
      cc: null,
      from: [],
    });
    expect(m1.participants().length).toBe(0)

    const m2 = new Message({
      to: [evan],
      cc: [],
      bcc: [],
      from: [ben],
    });
    expect(m2.participants().length).toBe(2)

    const m3 = new Message({
      to: [evan],
      cc: [evan],
      bcc: [evan],
      from: [evan],
    });
    expect(m3.participants().length).toBe(1)

    const m4 = new Message({
      to: [evan],
      cc: [ben, team, noEmail],
      bcc: [team],
      from: [team],
    });
    // because contact 4 has no email
    expect(m4.participants().length).toBe(3)

    const m5 = new Message({
      to: [evan],
      cc: [],
      bcc: [team],
      from: [ben],
    });
    // because we exclude bccs
    expect(m5.participants().length).toBe(2)
  });

  describe("participant replies", () => {
    const cases = [
      // Basic cases
      {
        msg: new Message({
          from: [evan],
          to: [me],
          cc: [],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [me],
          cc: [ben],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [ben],
          cc: [me],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [me],
          cc: [ben, team, evan],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [ben, team],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [me, ben, evan, ben, ben, evan],
          cc: [],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [me, ben],
          cc: [team, edgehill],
          bcc: [evan, me, ben],
        }),
        expected: {
          to: [evan],
          cc: [ben, team, edgehill],
        },
      },

      // From me (replying to a message I just sent)
      {
        msg: new Message({
          from: [me],
          to: [me],
          cc: [],
          bcc: [],
        }),
        expected: {
          to: [me],
          cc: [],
        },
      },
      {
        msg: new Message({
          from: [me],
          to: [ben],
          cc: [],
          bcc: [],
        }),
        expected: {
          to: [ben],
          cc: [],
        },
      },
      {
        msg: new Message({
          from: [me],
          to: [ben, team, ben],
          cc: [edgehill],
          bcc: [],
        }),
        expected: {
          to: [ben, team],
          cc: [edgehill],
        },
      },
      {
        msg: new Message({
          from: [me],
          to: [ben, team, ben],
          cc: [edgehill],
          bcc: [],
        }),
        expected: {
          to: [ben, team],
          cc: [edgehill],
        },
      },
      // From me in cases my similar alias is used
      {
        msg: new Message({
          from: [me],
          to: [almostMe],
          cc: [ben],
          bcc: [],
        }),
        expected: {
          to: [almostMe],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [me],
          to: [me, almostMe, me],
          cc: [ben, almostMe, me, me, ben, ben],
          bcc: [],
        }),
        expected: {
          to: [me],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [almostMe],
          to: [me],
          cc: [ben],
          bcc: [],
        }),
        expected: {
          to: [me],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [almostMe],
          to: [almostMe],
          cc: [ben],
          bcc: [],
        }),
        expected: {
          to: [almostMe],
          cc: [ben],
        },
      },

      // Cases when I'm on email lists
      {
        msg: new Message({
          from: [evan],
          to: [team],
          cc: [],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [team],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [team],
          cc: [ben, edgehill],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [team, ben, edgehill],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [team],
          cc: [me],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [team],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [team, me],
          cc: [ben],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [team, ben],
        },
      },

      // Cases when I'm bcc'd
      {
        msg: new Message({
          from: [evan],
          to: [],
          cc: [],
          bcc: [me],
        }),
        expected: {
          to: [evan],
          cc: [],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [ben],
          cc: [],
          bcc: [me],
        }),
        expected: {
          to: [evan],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [ben],
          cc: [team, edgehill],
          bcc: [me],
        }),
        expected: {
          to: [evan],
          cc: [ben, team, edgehill],
        },
      },

      // Cases my similar alias is used
      {
        msg: new Message({
          from: [evan],
          to: [almostMe],
          cc: [],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [ben],
          cc: [almostMe],
          bcc: [],
        }),
        expected: {
          to: [evan],
          cc: [ben],
        },
      },
      {
        msg: new Message({
          from: [evan],
          to: [ben],
          cc: [],
          bcc: [almostMe],
        }),
        expected: {
          to: [evan],
          cc: [ben],
        },
      },
    ]

    const itString = (prefix, msg) => (
      `${prefix} from: ${msg.from.map((c) => c.email).join(', ')} | to: ${msg.to.map((c) => c.email).join(', ')} | cc: ${msg.cc.map((c) => c.email).join(', ')} | bcc: ${msg.bcc.map((c) => c.email).join(', ')}`
    )

    it("thinks me and almostMe are equivalent", () => {
      expect(Utils.emailIsEquivalent(me.email, almostMe.email)).toBe(true)
      expect(Utils.emailIsEquivalent(ben.email, me.email)).toBe(false)
    });

    cases.forEach(({msg, expected}) => {
      it(itString("Reply All:", msg), () => {
        expect(msg.participantsForReplyAll()).toEqual(expected)
      });

      it(itString("Reply:", msg), () => {
        const {to, cc} = msg.participantsForReply()
        expect(to).toEqual(expected.to)
        expect(cc).toEqual([])
      });
    });
  });

  describe("participantsForReplyAll", () => {});
});
