{Message} = require 'nylas-exports'

SignatureComposerExtension = require '../lib/signature-composer-extension'

describe "SignatureComposerExtension", ->
  describe "prepareNewDraft", ->
    describe "when a signature is defined", ->
      beforeEach ->
        @signature = '<div id="signature">This is my signature.</div>'
        spyOn(NylasEnv.config, 'get').andCallFake =>
          @signature

      it "should insert the signature at the end of the message or before the first blockquote and have a newline", ->
        a = new Message
          draft: true
          body: 'This is a test! <blockquote>Hello world</blockquote>'
        b = new Message
          draft: true
          body: 'This is a another test.'

        SignatureComposerExtension.prepareNewDraft(a)
        expect(a.body).toEqual('This is a test! <br/><div class="nylas-n1-signature"><div id="signature">This is my signature.</div></div><blockquote>Hello world</blockquote>')
        SignatureComposerExtension.prepareNewDraft(b)
        expect(b.body).toEqual('This is a another test.<br/><div class="nylas-n1-signature"><div id="signature">This is my signature.</div></div>')

    describe "when a signature is not defined", ->
      beforeEach ->
        spyOn(NylasEnv.config, 'get').andCallFake ->
          null

      it "should not do anything", ->
        a = new Message
          draft: true
          body: 'This is a test! <blockquote>Hello world</blockquote>'
        SignatureComposerExtension.prepareNewDraft(a)
        expect(a.body).toEqual('This is a test! <blockquote>Hello world</blockquote>')
