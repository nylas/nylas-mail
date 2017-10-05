/* eslint quote-props: 0 */
import { SignatureStore } from 'mailspring-exports';

let SIGNATURES = {
  '1': {
    id: '1',
    title: 'one',
    body: 'first test signature!',
  },
  '2': {
    id: '2',
    title: 'two',
    body: 'Here is my second sig!',
  },
};

const DEFAULTS = {
  'one@nylas.com': '2',
  'two@nylas.com': '2',
  'three@nylas.com': null,
};

describe('SignatureStore', function signatureStore() {
  beforeEach(() => {
    spyOn(AppEnv.config, 'get').andCallFake(key => (key === 'signatures' ? SIGNATURES : null));

    spyOn(SignatureStore, '_saveSignatures').andCallFake(() => {
      AppEnv.config.set(`signatures`, SignatureStore.signatures);
    });
    spyOn(SignatureStore, 'signatureForEmail').andCallFake(email => SIGNATURES[DEFAULTS[email]]);
    spyOn(SignatureStore, 'selectedSignature').andCallFake(() => SIGNATURES['1']);
    SignatureStore.activate();
  });

  describe('signatureForAccountId', () => {
    it('should return the default signature for that account', () => {
      const titleForAccount1 = SignatureStore.signatureForEmail('one@nylas.com').title;
      expect(titleForAccount1).toEqual(SIGNATURES['2'].title);
      const account2Def = SignatureStore.signatureForEmail('three@nylas.com');
      expect(account2Def).toEqual(undefined);
    });
  });

  describe('removeSignature', () => {
    beforeEach(() => {
      spyOn(AppEnv.config, 'set').andCallFake((key, newObject) => {
        if (key === 'signatures') {
          SIGNATURES = newObject;
        }
      });
    });
    it('should remove the signature from our list of signatures', () => {
      const toRemove = SIGNATURES[SignatureStore.selectedSignatureId];
      SignatureStore._onRemoveSignature(toRemove);
      expect(SIGNATURES['1']).toEqual(undefined);
    });
    it('should reset selectedSignatureId to a different signature', () => {
      const toRemove = SIGNATURES[SignatureStore.selectedSignatureId];
      SignatureStore._onRemoveSignature(toRemove);
      expect(SignatureStore.selectedSignatureId).toNotEqual('1');
    });
  });
});
