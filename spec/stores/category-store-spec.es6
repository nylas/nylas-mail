import {
  Rx,
  AccountStore,
  CategoryStore,
  NylasSyncStatusStore,
} from 'nylas-exports';

xdescribe('CategoryStore', function categoryStore() {
  beforeEach(() => {
    spyOn(AccountStore, 'accountForId').andReturn({categoryCollection: () => 'labels'})
  });

  describe('whenCategoriesReady', () => {
    it('resolves immediately if sync is done and cache is populated', () => {
      spyOn(NylasSyncStatusStore, 'isSyncCompleteForAccount').andReturn(true)
      spyOn(CategoryStore, 'categories').andReturn([{name: 'inbox'}])
      spyOn(Rx.Observable, 'fromStore')
      waitsForPromise(() => {
        const promise = CategoryStore.whenCategoriesReady('a1')
        expect(promise.isResolved()).toBe(true)
        return promise.then(() => {
          expect(Rx.Observable.fromStore).not.toHaveBeenCalled()
        })
      })
    });

    it('resolves only when sync is done even if cache is already populated', () => {
      spyOn(NylasSyncStatusStore, 'isSyncCompleteForAccount').andReturn(false)
      spyOn(CategoryStore, 'categories').andReturn([{name: 'inbox'}])
      waitsForPromise(() => {
        const promise = CategoryStore.whenCategoriesReady('a1')
        expect(promise.isResolved()).toBe(false)

        jasmine.unspy(NylasSyncStatusStore, 'isSyncCompleteForAccount')
        spyOn(NylasSyncStatusStore, 'isSyncCompleteForAccount').andReturn(true)
        NylasSyncStatusStore.trigger()

        return promise.then(() => {
          expect(promise.isResolved()).toBe(true)
        })
      })
    });

    it('resolves only when cache is populated even if sync is done', () => {
      spyOn(NylasSyncStatusStore, 'isSyncCompleteForAccount').andReturn(true)
      spyOn(CategoryStore, 'categories').andReturn([])
      waitsForPromise(() => {
        const promise = CategoryStore.whenCategoriesReady('a1')
        expect(promise.isResolved()).toBe(false)

        jasmine.unspy(CategoryStore, 'categories')
        spyOn(CategoryStore, 'categories').andReturn([{name: 'inbox'}])
        CategoryStore.trigger()

        return promise.then(() => {
          expect(promise.isResolved()).toBe(true)
        })
      })
    });
  });
});
