import _ from 'underscore';

import {
  File,
  Actions,
  Thread,
  Contact,
  Message,
  DraftStore,
  AccountStore,
  DatabaseStore,
  AttachmentStore,
  SanitizeTransformer,
  InlineStyleTransformer,
} from 'mailspring-exports';

import DraftFactory from '../../src/flux/stores/draft-factory';

let msgFromMe = null;
let fakeThread = null;
let fakeMessage1 = null;
let msgWithReplyTo = null;
let fakeMessageWithFiles = null;
let msgWithReplyToDuplicates = null;
let msgWithReplyToFromMe = null;
let account = null;
const downloadData = {};

const expectContactsEqual = (a, b) => {
  expect(a.map(c => c.email).sort()).toEqual(b.map(c => c.email).sort());
};

describe('DraftFactory', function draftFactory() {
  beforeEach(() => {
    // Out of the scope of these specs
    spyOn(InlineStyleTransformer, 'run').andCallFake(input => Promise.resolve(input));
    spyOn(SanitizeTransformer, 'run').andCallFake(input => Promise.resolve(input));
    spyOn(AttachmentStore, 'getDownloadDataForFile').andCallFake(fid => {
      return downloadData[fid];
    });

    account = AccountStore.accounts()[0];
    const files = [
      new File({ filename: 'test.jpg', accountId: account.id }),
      new File({ filename: 'test.pdj', accountId: account.id }),
    ];
    files.forEach(file => {
      downloadData[file.id] = {
        fileId: file.id,
        filename: file.filename,
      };
    });

    fakeThread = new Thread({
      id: 'fake-thread-id',
      accountId: account.id,
      subject: 'Fake Subject',
    });

    fakeMessage1 = new Message({
      id: 'fake-message-1',
      headerMessageId: 'fake-message-1@localhost',
      accountId: account.id,
      to: [new Contact({ email: 'ben@nylas.com' }), new Contact({ email: 'evan@nylas.com' })],
      cc: [new Contact({ email: 'mg@nylas.com' }), account.me()],
      bcc: [new Contact({ email: 'recruiting@nylas.com' })],
      from: [new Contact({ email: 'customer@example.com', name: 'Customer' })],
      threadId: 'fake-thread-id',
      body: 'Fake Message 1',
      subject: 'Fake Subject',
      date: new Date(1415814587),
    });

    fakeMessageWithFiles = new Message({
      id: 'fake-message-with-files',
      headerMessageId: 'fake-message-with-files@localhost',
      accountId: account.id,
      to: [new Contact({ email: 'ben@nylas.com' }), new Contact({ email: 'evan@nylas.com' })],
      cc: [new Contact({ email: 'mg@nylas.com' }), account.me()],
      bcc: [new Contact({ email: 'recruiting@nylas.com' })],
      from: [new Contact({ email: 'customer@example.com', name: 'Customer' })],
      files: files,
      threadId: 'fake-thread-id',
      body: 'Fake Message 1',
      subject: 'Fake Subject',
      date: new Date(1415814587),
    });

    msgFromMe = new Message({
      id: 'fake-message-3',
      headerMessageId: 'fake-message-3@localhost',
      accountId: account.id,
      to: [new Contact({ email: '1@1.com' }), new Contact({ email: '2@2.com' })],
      cc: [new Contact({ email: '3@3.com' }), new Contact({ email: '4@4.com' })],
      bcc: [new Contact({ email: '5@5.com' }), new Contact({ email: '6@6.com' })],
      from: [account.me()],
      threadId: 'fake-thread-id',
      body: 'Fake Message 2',
      subject: 'Re: Fake Subject',
      date: new Date(1415814587),
    });

    msgWithReplyTo = new Message({
      id: 'fake-message-reply-to',
      headerMessageId: 'fake-message-reply-to@localhost',
      accountId: account.id,
      to: [new Contact({ email: '1@1.com' }), new Contact({ email: '2@2.com' })],
      cc: [new Contact({ email: '3@3.com' }), new Contact({ email: '4@4.com' })],
      bcc: [new Contact({ email: '5@5.com' }), new Contact({ email: '6@6.com' })],
      replyTo: [new Contact({ email: 'reply-to@5.com' }), new Contact({ email: 'reply-to@6.com' })],
      from: [new Contact({ email: 'from@5.com' })],
      threadId: 'fake-thread-id',
      body: 'Fake Message 2',
      subject: 'Re: Fake Subject',
      date: new Date(1415814587),
    });

    msgWithReplyToFromMe = new Message({
      accountId: account.id,
      threadId: 'fake-thread-id',
      from: [account.me()],
      to: [new Contact({ email: 'tiffany@popular.com', name: 'Tiffany' })],
      replyTo: [new Contact({ email: 'danco@gmail.com', name: 'danco@gmail.com' })],
    });

    msgWithReplyToDuplicates = new Message({
      id: 'fake-message-reply-to-duplicates',
      headerMessageId: 'fake-message-reply-to-duplicates@localhost',
      accountId: account.id,
      to: [new Contact({ email: '1@1.com' }), new Contact({ email: '2@2.com' })],
      cc: [new Contact({ email: '1@1.com' }), new Contact({ email: '4@4.com' })],
      from: [new Contact({ email: 'reply-to@5.com' })],
      replyTo: [new Contact({ email: 'reply-to@5.com' })],
      threadId: 'fake-thread-id',
      body: 'Fake Message Duplicates',
      subject: 'Re: Fake Subject',
      date: new Date(1415814587),
    });
  });

  describe('creating drafts', () => {
    describe('createDraftForReply', () => {
      it('should be empty string', () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
          }).then(draft => {
            expect(draft.body).toEqual('');
          });
        });
      });

      it("should address the message to the previous message's sender", () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
          }).then(draft => {
            expect(draft.to).toEqual(fakeMessage1.from);
          });
        });
      });

      it("should set the replyToHeaderMessageId to the previous message's ids", () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
          }).then(draft => {
            expect(draft.replyToHeaderMessageId).toEqual(fakeMessage1.headerMessageId);
          });
        });
      });

      it('should set the accountId and from address based on the message', () => {
        waitsForPromise(() => {
          const secondAccount = AccountStore.accounts()[1];
          fakeMessage1.to = [
            new Contact({ email: secondAccount.emailAddress }),
            new Contact({ email: 'evan@nylas.com' }),
          ];
          fakeMessage1.accountId = secondAccount.id;
          fakeThread.accountId = secondAccount.id;

          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
          }).then(draft => {
            expect(draft.accountId).toEqual(secondAccount.id);
            expect(draft.from[0].email).toEqual(secondAccount.defaultMe().email);
          });
        });
      });

      describe('when the email is TO an alias', () => {
        it('should use the alias as the from address', () => {
          waitsForPromise(() => {
            fakeMessage1.to = [
              new Contact({ email: TEST_ACCOUNT_ALIAS_EMAIL }),
              new Contact({ email: 'evan@nylas.com' }),
            ];

            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: fakeMessage1,
              type: 'reply',
            }).then(draft => {
              expect(draft.accountId).toEqual(TEST_ACCOUNT_ID);
              expect(draft.from[0].email).toEqual(TEST_ACCOUNT_ALIAS_EMAIL);
            });
          });
        });
      });

      describe("when the email is CC'd to an alias", () => {
        it('should use the alias as the from address', () => {
          waitsForPromise(() => {
            fakeMessage1.to = [new Contact({ email: 'juan@nylas.com' })];
            fakeMessage1.cc = [
              new Contact({ email: TEST_ACCOUNT_ALIAS_EMAIL }),
              new Contact({ email: 'evan@nylas.com' }),
            ];

            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: fakeMessage1,
              type: 'reply',
            }).then(draft => {
              expect(draft.accountId).toEqual(TEST_ACCOUNT_ID);
              expect(draft.from[0].email).toEqual(TEST_ACCOUNT_ALIAS_EMAIL);
            });
          });
        });
      });

      it('should make the subject the subject of the message, not the thread', () => {
        fakeMessage1.subject = 'OLD SUBJECT';
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
          }).then(draft => {
            expect(draft.subject).toEqual('Re: OLD SUBJECT');
          });
        });
      });

      it('should change the subject from Fwd: back to Re: if necessary', () => {
        fakeMessage1.subject = 'Fwd: This is my DRAFT';
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
          }).then(draft => {
            expect(draft.subject).toEqual('Re: This is my DRAFT');
          });
        });
      });
    });

    describe('type: reply', () => {
      describe("when the message provided as context has one or more 'ReplyTo' recipients", () => {
        it("addresses the draft to all of the message's 'ReplyTo' recipients", () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgWithReplyTo,
              type: 'reply',
            }).then(draft => {
              expect(draft.to).toEqual(msgWithReplyTo.replyTo);
              expect(draft.cc.length).toBe(0);
              expect(draft.bcc.length).toBe(0);
            });
          });
        });

        it("addresses the draft to all of the message's 'ReplyTo' recipients, even if the message is 'From' you", () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgWithReplyToFromMe,
              type: 'reply',
            }).then(draft => {
              expect(draft.to).toEqual(msgWithReplyToFromMe.replyTo);
              expect(draft.cc.length).toBe(0);
              expect(draft.bcc.length).toBe(0);
            });
          });
        });
      });

      describe('when the message provided as context was sent by the current user', () => {
        it("addresses the draft to all of the last messages's 'To' recipients", () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgFromMe,
              type: 'reply',
            }).then(draft => {
              expect(draft.to).toEqual(msgFromMe.to);
              expect(draft.cc.length).toBe(0);
              expect(draft.bcc.length).toBe(0);
            });
          });
        });
      });
    });

    describe('type: reply-all', () => {
      it('should include people in the cc field', () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply-all',
          }).then(draft => {
            const ccEmails = draft.cc.map(cc => cc.email);
            expect(ccEmails.sort()).toEqual(['ben@nylas.com', 'evan@nylas.com', 'mg@nylas.com']);
          });
        });
      });

      it("should not include people who were bcc'd on the previous message", () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply-all',
          }).then(draft => {
            expect(draft.bcc).toEqual([]);
            expect(draft.cc.indexOf(fakeMessage1.bcc[0])).toEqual(-1);
          });
        });
      });

      it("should not include you when you were cc'd on the previous message", () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply-all',
          }).then(draft => {
            const ccEmails = draft.cc.map(cc => cc.email);
            expect(ccEmails.indexOf(account.me().email)).toEqual(-1);
          });
        });
      });

      describe("when the message provided as context has one or more 'ReplyTo' recipients", () => {
        it("addresses the draft to all of the message's 'ReplyTo' recipients", () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgWithReplyTo,
              type: 'reply-all',
            }).then(draft => {
              expect(draft.to).toEqual(msgWithReplyTo.replyTo);
            });
          });
        });

        it("addresses the draft to all of the message's 'ReplyTo' recipients, even if the message is 'From' you", () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgWithReplyToFromMe,
              type: 'reply-all',
            }).then(draft => {
              expect(draft.to).toEqual(msgWithReplyToFromMe.replyTo);
            });
          });
        });

        it("should not include the message's 'From' recipient in any field", () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgWithReplyTo,
              type: 'reply-all',
            }).then(draft => {
              const all = [].concat(draft.to, draft.cc, draft.bcc);
              const match = _.find(all, c => c.email === msgWithReplyTo.from[0].email);
              expect(match).toEqual(undefined);
            });
          });
        });
      });

      describe("when the message provided has one or more 'ReplyTo' recipients and duplicates in the To/Cc fields", () => {
        it('should unique the to/cc fields', () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgWithReplyToDuplicates,
              type: 'reply-all',
            }).then(draft => {
              const ccEmails = draft.cc.map(cc => cc.email);
              expect(ccEmails.sort()).toEqual(['1@1.com', '2@2.com', '4@4.com']);
              const toEmails = draft.to.map(to => to.email);
              expect(toEmails.sort()).toEqual(['reply-to@5.com']);
            });
          });
        });
      });

      describe('when the message provided as context was sent by the current user', () => {
        it("addresses the draft to all of the last messages's recipients", () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForReply({
              thread: fakeThread,
              message: msgFromMe,
              type: 'reply-all',
            }).then(draft => {
              expect(draft.to).toEqual(msgFromMe.to);
              expect(draft.cc).toEqual(msgFromMe.cc);
              expect(draft.bcc.length).toBe(0);
            });
          });
        });
      });
    });

    describe('onComposeForward', () => {
      beforeEach(() => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForForward({
            thread: fakeThread,
            message: fakeMessage1,
          }).then(draft => {
            this.model = draft;
          });
        });
      });

      it('should include forwarded message text, in a div rather than a blockquote', () => {
        expect(this.model.body.indexOf('gmail_quote') > 0).toBe(true);
        expect(this.model.body.indexOf('blockquote') > 0).toBe(false);
        expect(this.model.body.indexOf(fakeMessage1.body) > 0).toBe(true);
        expect(this.model.body.indexOf('---------- Forwarded message ---------') > 0).toBe(true);
        expect(this.model.body.indexOf('From: Customer &lt;customer@example.com&gt;') > 0).toBe(
          true
        );
        expect(this.model.body.indexOf('Subject: Fake Subject') > 0).toBe(true);
        expect(this.model.body.indexOf('To: ben@nylas.com, evan@nylas.com') > 0).toBe(true);
        expect(
          this.model.body.indexOf('Cc: mg@nylas.com, Nylas Test &lt;tester@nylas.com&gt;') > 0
        ).toBe(true);
      });

      it("should not mention BCC'd recipients in the forwarded message header", () => {
        expect(this.model.body.indexOf('recruiting@nylas.com') > 0).toBe(false);
      });
      it('should not address the message to anyone', () => {
        expect(this.model.to).toEqual([]);
        expect(this.model.cc).toEqual([]);
        expect(this.model.bcc).toEqual([]);
      });

      it('should not set the replyToHeaderMessageId', () => {
        expect(this.model.replyToHeaderMessageId).toEqual(undefined);
      });

      it('should sanitize the HTML', () => {
        expect(InlineStyleTransformer.run).toHaveBeenCalled();
        expect(SanitizeTransformer.run).toHaveBeenCalled();
      });

      it('should include the attached files as files', () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForForward({
            thread: fakeThread,
            message: fakeMessageWithFiles,
          }).then(draft => {
            expect(draft.files.length).toBe(2);
            expect(draft.files[0].filename).toBe('test.jpg');
            expect(draft.files[1].filename).toBe('test.pdj');
          });
        });
      });

      it('should make the subject the subject of the message, not the thread', () => {
        fakeMessage1.subject = 'OLD SUBJECT';
        waitsForPromise(() => {
          return DraftFactory.createDraftForForward({
            thread: fakeThread,
            message: fakeMessage1,
          }).then(draft => {
            expect(draft.subject).toEqual('Fwd: OLD SUBJECT');
          });
        });
      });

      it('should change the subject from Re: back to Fwd: if necessary', () => {
        fakeMessage1.subject = 'Re: This is my DRAFT';
        waitsForPromise(() => {
          return DraftFactory.createDraftForForward({
            thread: fakeThread,
            message: fakeMessage1,
          }).then(draft => {
            expect(draft.subject).toEqual('Fwd: This is my DRAFT');
          });
        });
      });
    });
  });

  describe('createOrUpdateDraftForReply', () => {
    it('should throw an exception unless you provide `reply` or `reply-all`', () => {
      expect(() =>
        DraftFactory.createOrUpdateDraftForReply({
          thread: fakeThread,
          message: fakeMessage1,
          type: 'wrong',
        })
      ).toThrow();
    });

    describe('when there is already a draft in reply to the same message the thread', () => {
      beforeEach(() => {
        this.existingDraft = new Message({
          id: 'asd',
          accountId: TEST_ACCOUNT_ID,
          replyToHeaderMessageId: fakeMessage1.headerMessageId,
          threadId: fakeMessage1.threadId,
          draft: true,
        });
        this.sessionStub = {
          changes: {
            add: jasmine.createSpy('add'),
          },
        };
        spyOn(Actions, 'focusDraft');
        spyOn(DatabaseStore, 'run').andReturn(Promise.resolve([fakeMessage1, this.existingDraft]));
        spyOn(DraftStore, 'sessionForClientId').andReturn(Promise.resolve(this.sessionStub));
      });

      describe('when reply-all is passed', () => {
        it('should add missing participants', async () => {
          this.existingDraft.to = fakeMessage1.participantsForReply().to;
          this.existingDraft.cc = fakeMessage1.participantsForReply().cc;
          const { to, cc } = await DraftFactory.createOrUpdateDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply-all',
            behavior: 'prefer-existing',
          });
          expectContactsEqual(to, fakeMessage1.participantsForReplyAll().to);
          expectContactsEqual(cc, fakeMessage1.participantsForReplyAll().cc);
        });

        it('should not blow away other participants who have been added to the draft', async () => {
          const randomA = new Contact({ email: 'other-guy-a@gmail.com' });
          const randomB = new Contact({ email: 'other-guy-b@gmail.com' });
          this.existingDraft.to = fakeMessage1.participantsForReply().to.concat([randomA]);
          this.existingDraft.cc = fakeMessage1.participantsForReply().cc.concat([randomB]);
          const { to, cc } = await DraftFactory.createOrUpdateDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply-all',
            behavior: 'prefer-existing',
          });
          expectContactsEqual(to, fakeMessage1.participantsForReplyAll().to.concat([randomA]));
          expectContactsEqual(cc, fakeMessage1.participantsForReplyAll().cc.concat([randomB]));
        });
      });

      describe('when reply is passed', () => {
        it('should remove participants present in the reply-all participant set and not in the reply set', async () => {
          this.existingDraft.to = fakeMessage1.participantsForReplyAll().to;
          this.existingDraft.cc = fakeMessage1.participantsForReplyAll().cc;
          const { to, cc } = await DraftFactory.createOrUpdateDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
            behavior: 'prefer-existing',
          });
          expectContactsEqual(to, fakeMessage1.participantsForReply().to);
          expectContactsEqual(cc, fakeMessage1.participantsForReply().cc);
        });

        it('should not blow away other participants who have been added to the draft', async () => {
          const randomA = new Contact({ email: 'other-guy-a@gmail.com' });
          const randomB = new Contact({ email: 'other-guy-b@gmail.com' });
          this.existingDraft.to = fakeMessage1.participantsForReplyAll().to.concat([randomA]);
          this.existingDraft.cc = fakeMessage1.participantsForReplyAll().cc.concat([randomB]);
          const { to, cc } = await DraftFactory.createOrUpdateDraftForReply({
            thread: fakeThread,
            message: fakeMessage1,
            type: 'reply',
            behavior: 'prefer-existing',
          });
          expectContactsEqual(to, fakeMessage1.participantsForReply().to.concat([randomA]));
          expectContactsEqual(cc, fakeMessage1.participantsForReply().cc.concat([randomB]));
        });
      });
    });

    describe('when there is not an existing draft at the bottom of the thread', () => {
      beforeEach(() => {
        spyOn(Actions, 'focusDraft');
        spyOn(DatabaseStore, 'run').andCallFake(() => [fakeMessage1]);
        spyOn(DraftFactory, 'createDraftForReply');
      });

      it('should call through to createDraftForReply', async () => {
        await DraftFactory.createOrUpdateDraftForReply({
          thread: fakeThread,
          message: fakeMessage1,
          type: 'reply-all',
        });
        expect(DraftFactory.createDraftForReply).toHaveBeenCalledWith({
          thread: fakeThread,
          message: fakeMessage1,
          type: 'reply-all',
        });

        await DraftFactory.createOrUpdateDraftForReply({
          thread: fakeThread,
          message: fakeMessage1,
          type: 'reply',
        });
        expect(DraftFactory.createDraftForReply).toHaveBeenCalledWith({
          thread: fakeThread,
          message: fakeMessage1,
          type: 'reply',
        });
      });
    });
  });

  describe('_fromContactForReply', () => {
    it('should work correctly in a range of test cases', () => {
      // Note: These specs are based on the second account hard-coded in SpecHelper
      account = AccountStore.accounts()[1];
      const cases = [
        {
          to: [new Contact({ name: 'Ben', email: 'ben@nylas.com' })], // user is not present, must have been BCC'd
          cc: [],
          expected: account.defaultMe(),
        },
        {
          to: [new Contact({ name: 'Second Support', email: 'second@gmail.com' })], // only name identifies alias
          cc: [],
          expected: new Contact({ name: 'Second Support', email: 'second@gmail.com' }),
        },
        {
          to: [new Contact({ name: 'Second Wrong!', email: 'second+alternate@gmail.com' })], // only email identifies alias, name wrong
          cc: [],
          expected: new Contact({ name: 'Second Alternate', email: 'second+alternate@gmail.com' }),
        },
        {
          to: [new Contact({ name: 'Second Alternate', email: 'second+alternate@gmail.com' })], // exact alias match
          cc: [],
          expected: new Contact({ name: 'Second Alternate', email: 'second+alternate@gmail.com' }),
        },
        {
          to: [new Contact({ email: 'second+third@gmail.com' })], // exact alias match, name not present
          cc: [],
          expected: new Contact({ name: 'Second', email: 'second+third@gmail.com' }),
        },
        {
          to: [new Contact({ email: 'ben@nylas.com' })],
          cc: [new Contact({ email: 'second+third@gmail.com' })], // exact alias match, but in CC
          expected: new Contact({ name: 'Second', email: 'second+third@gmail.com' }),
        },
      ];
      cases.forEach(({ to, cc, expected }) => {
        const contact = DraftFactory._fromContactForReply(
          new Message({
            accountId: account.id,
            to: to,
            cc: cc,
          })
        );
        expect(contact.name).toEqual(expected.name);
        expect(contact.email).toEqual(expected.email);
      });
    });
  });

  describe('createDraftForMailto', () => {
    describe('parameters in the URL', () => {
      let expected = null;
      beforeEach(() => {
        expected = 'EmailSubjectLOLOL';
      });

      it('works for lowercase', () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForMailto(
            `mailto:asdf@asdf.com?subject=${expected}`
          ).then(draft => {
            expect(draft.subject).toBe(expected);
          });
        });
      });

      it('works for title case', () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForMailto(
            `mailto:asdf@asdf.com?Subject=${expected}`
          ).then(draft => {
            expect(draft.subject).toBe(expected);
          });
        });
      });

      it('works for uppercase', () => {
        waitsForPromise(() => {
          return DraftFactory.createDraftForMailto(
            `mailto:asdf@asdf.com?SUBJECT=${expected}`
          ).then(draft => {
            expect(draft.subject).toBe(expected);
          });
        });
      });
      ['mailto', 'mail', ''].forEach(url => {
        it(`rejects gracefully on super mangled mailto link: ${url}`, () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForMailto(url)
              .then(() => {
                expect('resolved').toBe(false);
              })
              .catch(() => {});
          });
        });
      });
    });

    describe('should correctly instantiate drafts for a wide range of mailto URLs', () => {
      const links = [
        'mailto:',
        'mailto://bengotow@gmail.com',
        'mailto:bengotow@gmail.com',
        'mailto:mg%40nylas.com',
        'mailto:?subject=%1z2a', // fails uriDecode
        'mailto:?subject=%52z2a', // passes uriDecode
        'mailto:?subject=Martha Stewart',
        'mailto:?subject=Martha Stewart&cc=cc@nylas.com',
        'mailto:?subject=Martha Stewart&cc=cc@nylas.com;bengotow@gmail.com',
        'mailto:bengotow@gmail.com&subject=Martha Stewart&cc=cc@nylas.com',
        'mailto:bengotow@gmail.com?subject=Martha%20Stewart&cc=cc@nylas.com&bcc=bcc@nylas.com',
        'mailto:bengotow@gmail.com?subject=Martha%20Stewart&cc=cc@nylas.com&bcc=Ben <bcc@nylas.com>',
        'mailto:bengotow@gmail.com?subject=Martha%20Stewart&cc=cc@nylas.com&bcc=Ben <bcc@nylas.com>;Shawn <shawn@nylas.com>',
        'mailto:Ben Gotow <bengotow@gmail.com>,Shawn <shawn@nylas.com>?subject=Yes this is really valid',
        'mailto:Ben%20Gotow%20<bengotow@gmail.com>,Shawn%20<shawn@nylas.com>?subject=Yes%20this%20is%20really%20valid',
        'mailto:Reply <d+AORGpRdj0KXKUPBE1LoI0a30F10Ahj3wu3olS-aDk5_7K5Wu6WqqqG8t1HxxhlZ4KEEw3WmrSdtobgUq57SkwsYAH6tG57IrNqcQR0K6XaqLM2nGNZ22D2k@docs.google.com>?subject=Nilas%20Message%20to%20Customers',
        'mailto:email@address.com?&subject=test&body=type%20your%0Amessage%20here',
        'mailto:?body=type%20your%0D%0Amessage%0D%0Ahere',
        'mailto:?subject=Issues%20%C2%B7%20atom/electron%20%C2%B7%20GitHub&body=https://github.com/atom/electron/issues?utf8=&q=is%253Aissue+is%253Aopen+123%0A%0A',
      ];
      const expected = [
        new Message(),
        new Message({
          to: [new Contact({ name: 'bengotow@gmail.com', email: 'bengotow@gmail.com' })],
        }),
        new Message({
          to: [new Contact({ name: 'bengotow@gmail.com', email: 'bengotow@gmail.com' })],
        }),
        new Message({ to: [new Contact({ name: 'mg@nylas.com', email: 'mg@nylas.com' })] }),
        new Message({ subject: '%1z2a' }),
        new Message({ subject: 'Rz2a' }),
        new Message({ subject: 'Martha Stewart' }),
        new Message({
          cc: [new Contact({ name: 'cc@nylas.com', email: 'cc@nylas.com' })],
          subject: 'Martha Stewart',
        }),
        new Message({
          cc: [
            new Contact({ name: 'cc@nylas.com', email: 'cc@nylas.com' }),
            new Contact({ name: 'bengotow@gmail.com', email: 'bengotow@gmail.com' }),
          ],
          subject: 'Martha Stewart',
        }),
        new Message({
          to: [new Contact({ name: 'bengotow@gmail.com', email: 'bengotow@gmail.com' })],
          cc: [new Contact({ name: 'cc@nylas.com', email: 'cc@nylas.com' })],
          subject: 'Martha Stewart',
        }),
        new Message({
          to: [new Contact({ name: 'bengotow@gmail.com', email: 'bengotow@gmail.com' })],
          cc: [new Contact({ name: 'cc@nylas.com', email: 'cc@nylas.com' })],
          bcc: [new Contact({ name: 'bcc@nylas.com', email: 'bcc@nylas.com' })],
          subject: 'Martha Stewart',
        }),
        new Message({
          to: [new Contact({ name: 'bengotow@gmail.com', email: 'bengotow@gmail.com' })],
          cc: [new Contact({ name: 'cc@nylas.com', email: 'cc@nylas.com' })],
          bcc: [new Contact({ name: 'Ben', email: 'bcc@nylas.com' })],
          subject: 'Martha Stewart',
        }),
        new Message({
          to: [new Contact({ name: 'bengotow@gmail.com', email: 'bengotow@gmail.com' })],
          cc: [new Contact({ name: 'cc@nylas.com', email: 'cc@nylas.com' })],
          bcc: [
            new Contact({ name: 'Ben', email: 'bcc@nylas.com' }),
            new Contact({ name: 'Shawn', email: 'shawn@nylas.com' }),
          ]
        }),
        new Message({
          to: [
            new Contact({ name: 'Ben Gotow', email: 'bengotow@gmail.com' }),
            new Contact({ name: 'Shawn', email: 'shawn@nylas.com' }),
          ],
          subject: 'Yes this is really valid',
        }),
        new Message({
          to: [
            new Contact({ name: 'Ben Gotow', email: 'bengotow@gmail.com' }),
            new Contact({ name: 'Shawn', email: 'shawn@nylas.com' }),
          ],
          subject: 'Yes this is really valid',
        }),
        new Message({
          to: [
            new Contact({
              name: 'Reply',
              email:
                'd+AORGpRdj0KXKUPBE1LoI0a30F10Ahj3wu3olS-aDk5_7K5Wu6WqqqG8t1HxxhlZ4KEEw3WmrSdtobgUq57SkwsYAH6tG57IrNqcQR0K6XaqLM2nGNZ22D2k@docs.google.com',
            }),
          ],
          subject: 'Nilas Message to Customers',
        }),
        new Message({
          to: [new Contact({ name: 'email@address.com', email: 'email@address.com' })],
          subject: 'test',
          body: 'type your<br/>message here',
        }),
        new Message({
          to: [],
          body: 'type your<br/><br/>message<br/><br/>here',
        }),
        new Message({
          to: [],
          subject: 'Issues · atom/electron · GitHub',
          body:
            'https://github.com/atom/electron/issues?utf8=&q=is%3Aissue+is%3Aopen+123<br/><br/>',
        }),
      ];

      links.forEach((link, idx) => {
        it(`works for ${link}`, () => {
          waitsForPromise(() => {
            return DraftFactory.createDraftForMailto(link).then(draft => {
              const expectedDraft = expected[idx];
              expect(draft.subject).toEqual(expectedDraft.subject);
              if (expectedDraft.body) {
                expect(draft.body).toEqual(expectedDraft.body);
              }
              ['to', 'cc', 'bcc'].forEach(attr => {
                expectedDraft[attr].forEach((expectedContact, jdx) => {
                  const actual = draft[attr][jdx];
                  expect(actual instanceof Contact).toBe(true);
                  expect(actual.email).toEqual(expectedContact.email);
                  expect(actual.name).toEqual(expectedContact.name);
                });
              });
            });
          });
        });
      });
    });
  });
});
