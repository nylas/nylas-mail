import {Message} from 'nylas-exports';
import SignatureComposerExtension from '../lib/signature-composer-extension';

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
          body: 'This is a test! <blockquote>Hello world</blockquote>',
        });
        const b = new Message({
          draft: true,
          body: 'This is a another test.',
        });

        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual('This is a test! <div class="nylas-n1-signature"><div id="signature">This is my signature.</div></div><blockquote>Hello world</blockquote>');
        SignatureComposerExtension.prepareNewDraft({draft: b});
        expect(b.body).toEqual('This is a another test.<br/><br/><div class="nylas-n1-signature"><div id="signature">This is my signature.</div></div>');
      });

      it("should replace the signature if a signature is already present", ()=> {
        const a = new Message({
          draft: true,
          body: 'This is a test! <div class="nylas-n1-signature"><div>SIG</div></div><blockquote>Hello world</blockquote>',
        })
        const b = new Message({
          draft: true,
          body: 'This is a test! <div class="nylas-n1-signature"><div>SIG</div></div>',
        })
        const c = new Message({
          draft: true,
          body: 'This is a test! <div class="nylas-n1-signature"></div>',
        })
        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual(`This is a test! <div class="nylas-n1-signature">${this.signature}</div><blockquote>Hello world</blockquote>`);
        SignatureComposerExtension.prepareNewDraft({draft: b});
        expect(b.body).toEqual(`This is a test! <div class="nylas-n1-signature">${this.signature}</div>`);
        SignatureComposerExtension.prepareNewDraft({draft: c});
        expect(c.body).toEqual(`This is a test! <div class="nylas-n1-signature">${this.signature}</div>`);
      });
    });

    describe("when a signature is not defined", ()=> {
      beforeEach(()=> {
        spyOn(NylasEnv.config, 'get').andCallFake(()=> null);
      });

      it("should not do anything", ()=> {
        const a = new Message({
          draft: true,
          body: 'This is a test! <blockquote>Hello world</blockquote>',
        });
        SignatureComposerExtension.prepareNewDraft({draft: a});
        expect(a.body).toEqual('This is a test! <blockquote>Hello world</blockquote>');
      });
    });
  });
});
