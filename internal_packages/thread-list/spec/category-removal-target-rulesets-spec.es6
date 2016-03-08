import {AccountStore, CategoryStore} from 'nylas-exports'
import {Gmail} from '../lib/category-removal-target-rulesets'

describe('CategoryRemovalTargetRulesets', ()=> {
  describe('Gmail', ()=> {
    it('is a no op in archive, all, spam and sent', ()=> {
      expect(Gmail.all).toBe(null)
      expect(Gmail.sent).toBe(null)
      expect(Gmail.spam).toBe(null)
      expect(Gmail.archive).toBe(null)
    });

    describe('default', ()=> {
      it('moves to archive if account uses folders', ()=> {
        const account = {usesFolders: ()=> true}
        spyOn(AccountStore, 'accountForId').andReturn(account)
        spyOn(CategoryStore, 'getArchiveCategory').andReturn('archive')
        expect(Gmail.other('a1')).toEqual('archive')
      });

      it('moves to nowhere if account uses labels', ()=> {
        const account = {usesFolders: ()=> false}
        spyOn(AccountStore, 'accountForId').andReturn(account)
        expect(Gmail.other('a1')).toBe(null)
      });
    });
  });
});
