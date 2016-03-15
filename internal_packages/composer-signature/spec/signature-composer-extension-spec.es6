import {Message} from 'nylas-exports';
import SignatureComposerExtension from '../lib/signature-composer-extension';
import SignatureStore from '../lib/signature-store';

describe("SignatureComposerExtension", ()=> {
  describe("prepareNewDraft", ()=> {
    describe("when a signature is defined", ()=> {
      beforeEach(()=> {
        this.signature = '<div id="signature">This is my signature.</div>';
        spyOn(NylasEnv.config, 'get').andCallFake(()=> this.signature);
      });

      it("should insert the signature at the end of the message or before the first blockquote and have a newline", ()=> {
        const a = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a test! <blockquote>Hello world</blockquote>',
        });
        const b = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a another test.',
        });

        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual('This is a test! <div class="nylas-n1-signature"><div id="signature">This is my signature.</div></div><blockquote>Hello world</blockquote>');
        SignatureComposerExtension.prepareNewDraft({draft: b});
        expect(b.body).toEqual('This is a another test.<br/><br/><div class="nylas-n1-signature"><div id="signature">This is my signature.</div></div>');
      });

      it("should replace the signature if a signature is already present", ()=> {
        const scenarios = [
          {
            // With blockquote
            body: 'This is a test! <div class="nylas-n1-signature"><div>SIG</div></div><blockquote>Hello world</blockquote>',
            expected: `This is a test! <div class="nylas-n1-signature">${this.signature}</div><blockquote>Hello world</blockquote>`,
          },
          {
            // Populated signature div
            body: 'This is a test! <div class="nylas-n1-signature"><div>SIG</div></div>',
            expected: `This is a test! <div class="nylas-n1-signature">${this.signature}</div>`,
          },
          {
            // Empty signature div
            body: 'This is a test! <div class="nylas-n1-signature"></div>',
            expected: `This is a test! <div class="nylas-n1-signature">${this.signature}</div>`,
          },
          {
            // With newlines
            body: 'This is a test! <div class="nylas-n1-signature">\n<br>\n<div>SIG</div>\n</div>',
            expected: `This is a test! <div class="nylas-n1-signature">${this.signature}</div>`,
          },
        ]

        scenarios.forEach((scenario)=> {
          const message = new Message({
            draft: true,
            body: scenario.body,
            accountId: TEST_ACCOUNT_ID,
          })
          SignatureComposerExtension.prepareNewDraft({draft: message});
          expect(message.body).toEqual(scenario.expected)
        })
      });
    });

    describe("when no signature is present in the config file", ()=> {
      beforeEach(()=> {
        spyOn(NylasEnv.config, 'get').andCallFake(()=> undefined);
      });

      it("should insert the default signature", ()=> {
        const a = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a test! <blockquote>Hello world</blockquote>',
        });
        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual(`This is a test! <div class="nylas-n1-signature">${SignatureStore.DefaultSignature}</div><blockquote>Hello world</blockquote>`);
      });
    });


    describe("when a blank signature is present in the config file", ()=> {
      beforeEach(()=> {
        spyOn(NylasEnv.config, 'get').andCallFake(()=> "");
      });

      it("should insert nothing", ()=> {
        const a = new Message({
          draft: true,
          accountId: TEST_ACCOUNT_ID,
          body: 'This is a test! <blockquote>Hello world</blockquote>',
        });
        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual(`This is a test! <blockquote>Hello world</blockquote>`);
      });
    });
  });
});
