/* eslint quote-props: 0 */
import {SignatureStore} from 'nylas-exports'

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
}

const DEFAULTS = {
  11: '2',
  22: '2',
  33: null,
}

describe('SignatureStore', function signatureStore() {
  beforeEach(() => {
    spyOn(NylasEnv.config, 'get').andCallFake(() => SIGNATURES)

    spyOn(SignatureStore, '_saveSignatures').andCallFake(() => {
      NylasEnv.config.set(`nylas.signatures`, SignatureStore.signatures)
    })
    spyOn(SignatureStore, 'signatureForAccountId').andCallFake((accountId) => SIGNATURES[DEFAULTS[accountId]])
    spyOn(SignatureStore, 'selectedSignature').andCallFake(() => SIGNATURES['1'])
    SignatureStore.activate()
  })


  describe('signatureForAccountId', () => {
    it('should return the default signature for that account', () => {
      const titleForAccount11 = SignatureStore.signatureForAccountId(11).title
      expect(titleForAccount11).toEqual(SIGNATURES['2'].title)
      const account22Def = SignatureStore.signatureForAccountId(33)
      expect(account22Def).toEqual(undefined)
    })
  })

  describe('removeSignature', () => {
    beforeEach(() => {
      spyOn(NylasEnv.config, 'set').andCallFake((notImportant, newObject) => {
        SIGNATURES = newObject
      })
    })
    it('should remove the signature from our list of signatures', () => {
      const toRemove = SIGNATURES[SignatureStore.selectedSignatureId]
      SignatureStore._onRemoveSignature(toRemove)
      expect(SIGNATURES['1']).toEqual(undefined)
    })
    it('should reset selectedSignatureId to a different signature', () => {
      const toRemove = SIGNATURES[SignatureStore.selectedSignatureId]
      SignatureStore._onRemoveSignature(toRemove)
      expect(SignatureStore.selectedSignatureId).toNotEqual('1')
    })
  })
})
