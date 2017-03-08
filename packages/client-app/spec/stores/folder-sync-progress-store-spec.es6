import {FolderSyncProgressStore} from 'nylas-exports'

const store = FolderSyncProgressStore

xdescribe('FolderSyncProgressStore', function nylasSyncStatusStore() {
  beforeEach(() => {
    store._statesByAccount = {}
  });

  describe('isSyncCompleteForAccount', () => {
    describe('when model (collection) provided', () => {
      it('returns true if syncing for the given model and account is complete', () => {
        store._statesByAccount = {
          a1: {
            labels: {complete: true},
          },
        }
        expect(store.isSyncCompleteForAccount('a1', 'labels')).toBe(true)
      });

      it('returns false otherwise', () => {
        const states = [
          { a1: { labels: {complete: false} } },
          { a1: {} },
          {},
        ]
        states.forEach((state) => {
          store._statesByAccount = state
          expect(store.isSyncCompleteForAccount('a1', 'labels')).toBe(false)
        })
      });
    });

    describe('when model not provided', () => {
      it('returns true if sync is complete for all models for the given account', () => {
        store._statesByAccount = {
          a1: {
            labels: {complete: true},
            threads: {complete: true},
          },
        }
        expect(store.isSyncCompleteForAccount('a1')).toBe(true)
      });

      it('returns false otherwise', () => {
        store._statesByAccount = {
          a1: {
            labels: {complete: true},
            threads: {complete: false},
          },
        }
        expect(store.isSyncCompleteForAccount('a1')).toBe(false)
      });
    });
  });

  describe('isSyncComplete', () => {
    it('returns true if sync is complete for all accounts', () => {
      spyOn(store, 'isSyncCompleteForAccount').andReturn(true)
      store._statesByAccount = {
        a1: {},
        a2: {},
      }
      expect(store.isSyncComplete('a1')).toBe(true)
    });

    it('returns false otherwise', () => {
      spyOn(store, 'isSyncCompleteForAccount').andCallFake(acctId => acctId === 'a1')
      store._statesByAccount = {
        a1: {},
        a2: {},
      }
      expect(store.isSyncComplete('a1')).toBe(false)
    });
  });
});
