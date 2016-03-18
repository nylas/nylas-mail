import {Message} from 'nylas-exports';
import SignatureComposerExtension from '../lib/signature-composer-extension';
import SignatureStore from '../lib/signature-store';

const TEST_SIGNATURE = '<div class="something">This is my signature.</div>';

describe("SignatureComposerExtension", () => {
  describe("applyTransformsToDraft", () => {
    it("should unwrap the signature and remove the custom DOM element", () => {
      const a = new Message({
        draft: true,
        accountId: TEST_ACCOUNT_ID,
        body: `This is a test! <signature>${TEST_SIGNATURE}<br/></signature><div class="gmail_quote">Hello world</div>`,
      });
      const out = SignatureComposerExtension.applyTransformsToDraft({draft: a});
      expect(out.body).toEqual(`This is a test! <!-- <signature> -->${TEST_SIGNATURE}<br/><!-- </signature> --><div class="gmail_quote">Hello world</div>`);
    });
  });

  describe("prepareNewDraft", () => {
    describe("when a signature is defined", () => {
      beforeEach(() => {
        spyOn(NylasEnv.config, 'get').andCallFake(() => TEST_SIGNATURE);
      });

      it("should insert the signature at the end of the message or before the first quoted text block and have a newline", ()=> {
        const a = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a test! <div class="gmail_quote">Hello world</div>',
        });
        const b = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a another test.',
        });

        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual(`This is a test! <signature>${TEST_SIGNATURE}<br/></signature><div class="gmail_quote">Hello world</div>`);
        SignatureComposerExtension.prepareNewDraft({draft: b});
        expect(b.body).toEqual(`This is a another test.<signature><br/><br/>${TEST_SIGNATURE}</signature>`);
      });

      const scenarios = [
        {
          name: 'With blockquote',
          body: `This is a test! <signature><div>SIG</div></signature><div class="gmail_quote">Hello world</div>`,
          expected: `This is a test! <signature>${TEST_SIGNATURE}<br/></signature><div class="gmail_quote">Hello world</div>`,
        },
        {
          name: 'Populated signature div',
          body: `This is a test! <signature><br/><br/><div>SIG</div></signature>`,
          expected: `This is a test! <signature><br/><br/>${TEST_SIGNATURE}</signature>`,
        },
        {
          name: 'Empty signature div',
          body: 'This is a test! <signature></signature>',
          expected: `This is a test! <signature><br/><br/>${TEST_SIGNATURE}</signature>`,
        },
        {
          name: 'With newlines',
          body: 'This is a test! <signature>\n<br>\n<div>SIG</div>\n</signature>',
          expected: `This is a test! <signature><br/><br/>${TEST_SIGNATURE}</signature>`,
        },
      ]

      scenarios.forEach((scenario) => {
        it(`should replace the signature if a signature is already present (${scenario.name})`, () => {
          const message = new Message({
            draft: true,
            body: scenario.body,
            accountId: TEST_ACCOUNT_ID,
          })
          SignatureComposerExtension.prepareNewDraft({draft: message});
          expect(message.body).toEqual(scenario.expected)
        });
      });
    });

    describe("when no signature is present in the config file", () => {
      beforeEach(()=> {
        spyOn(NylasEnv.config, 'get').andCallFake(() => undefined);
      });

      it("should insert the default signature", () => {
        const a = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a test! <div class="gmail_quote">Hello world</div>',
        });
        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual(`This is a test! <signature>${SignatureStore.DefaultSignature}<br/></signature><div class="gmail_quote">Hello world</div>`);
      });
    });


    describe("when a blank signature is present in the config file", () => {
      beforeEach(() => {
        spyOn(NylasEnv.config, 'get').andCallFake(() => "");
      });

      it("should insert nothing", () => {
        const a = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a test! <div class="gmail_quote">Hello world</div>',
        });
        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual(`This is a test! <div class="gmail_quote">Hello world</div>`);
      });
    });
  });
});
