import {Message, SignatureStore} from 'nylas-exports';
import SignatureComposerExtension from '../lib/signature-composer-extension';

const TEST_ID = 1
const TEST_SIGNATURE = {
  id: TEST_ID,
  title: 'test-sig',
  body: '<div class="something">This is my signature.</div>',
}

const TEST_SIGNATURES = {}
TEST_SIGNATURES[TEST_ID] = TEST_SIGNATURE

describe('SignatureComposerExtension', function signatureComposerExtension() {
  describe("prepareNewDraft", () => {
    describe("when a signature is defined", () => {
      beforeEach(() => {
        spyOn(NylasEnv.config, 'get').andCallFake((key) =>
          (key === 'nylas.signatures' ? TEST_SIGNATURES : null)
        );
        spyOn(SignatureStore, 'signatureForEmail').andReturn(TEST_SIGNATURE)
        SignatureStore.activate()
      });

      it("should insert the signature at the end of the message or before the first quoted text block and have a newline", () => {
        const a = new Message({
          draft: true,
          from: ['one@nylas.com'],
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a test! <div class="gmail_quote">Hello world</div>',
        });
        const b = new Message({
          draft: true,
          from: ['one@nylas.com'],
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a another test.',
        });

        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual(`This is a test! <signature>${TEST_SIGNATURE.body}</signature><div class="gmail_quote">Hello world</div>`);
        SignatureComposerExtension.prepareNewDraft({draft: b});
        expect(b.body).toEqual(`This is a another test.<br><br><signature>${TEST_SIGNATURE.body}</signature>`);
      });

      const scenarios = [
        {
          name: 'With blockquote',
          body: `This is a test! <signature><div>SIG</div></signature><div class="gmail_quote">Hello world</div>`,
          expected: `This is a test! <signature>${TEST_SIGNATURE.body}</signature><div class="gmail_quote">Hello world</div>`,
        },
        {
          name: 'Populated signature div',
          body: `This is a test! <signature><div>SIG</div></signature>`,
          expected: `This is a test! <signature>${TEST_SIGNATURE.body}</signature>`,
        },
        {
          name: 'Empty signature div',
          body: 'This is a test! <signature></signature>',
          expected: `This is a test! <signature>${TEST_SIGNATURE.body}</signature>`,
        },
        {
          name: 'With newlines',
          body: 'This is a test!<br/> <signature>\n<br>\n<div>SIG</div>\n</signature>',
          expected: `This is a test!<br/> <signature>${TEST_SIGNATURE.body}</signature>`,
        },
      ]

      scenarios.forEach((scenario) => {
        it(`should replace the signature if a signature is already present (${scenario.name})`, () => {
          const message = new Message({
            draft: true,
            from: ['one@nylas.com'],
            body: scenario.body,
            accountId: TEST_ACCOUNT_ID,
          })
          SignatureComposerExtension.prepareNewDraft({draft: message});
          expect(message.body).toEqual(scenario.expected)
        });
      });
    });
  });
});
