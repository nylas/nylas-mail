import {
  AccountStore,
  CategoryStore,
  NylasAPI,
  Thread,
  Actions,
  Category,
} from 'nylas-exports'
import SnoozeUtils from '../lib/snooze-utils'
import SnoozeStore from '../lib/snooze-store'


describe('SnoozeStore', ()=> {
  beforeEach(()=> {
    this.store = new SnoozeStore('plug-id', 'plug-name')
    this.name = 'Snooze folder'
    this.accounts = [{id: 123}, {id: 321}]

    this.snoozeCatsByAccount = {
      '123': new Category({accountId: 123, displayName: this.name, serverId: 'sn-1'}),
      '321': new Category({accountId: 321, displayName: this.name, serverId: 'sn-2'}),
    }
    this.inboxCatsByAccount = {
      '123': new Category({accountId: 123, name: 'inbox', serverId: 'in-1'}),
      '321': new Category({accountId: 321, name: 'inbox', serverId: 'in-2'}),
    }
    this.threads = [
      new Thread({accountId: 123, serverId: 's-1'}),
      new Thread({accountId: 123, serverId: 's-2'}),
      new Thread({accountId: 321, serverId: 's-3'}),
    ]
    this.updatedThreadsByAccountId = {
      '123': {
        threads: [this.threads[0], this.threads[1]],
        snoozeCategoryId: 'sn-1',
        returnCategoryId: 'in-1',
      },
      '321': {
        threads: [this.threads[2]],
        snoozeCategoryId: 'sn-2',
        returnCategoryId: 'in-2',
      },
    }
    this.store.snoozeCategoriesPromise = Promise.resolve()
    spyOn(this.store, 'recordSnoozeEvent')
    spyOn(this.store, 'groupUpdatedThreads').andReturn(Promise.resolve(this.updatedThreadsByAccountId))

    spyOn(AccountStore, 'accountsForItems').andReturn(this.accounts)
    spyOn(NylasAPI, 'authPlugin').andReturn(Promise.resolve())
    spyOn(SnoozeUtils, 'moveThreadsToSnooze').andReturn(Promise.resolve(this.threads))
    spyOn(SnoozeUtils, 'moveThreadsFromSnooze')
    spyOn(Actions, 'setMetadata')
    spyOn(Actions, 'closePopover')
    spyOn(NylasEnv, 'reportError')
    spyOn(NylasEnv, 'showErrorDialog')
  })

  describe('groupUpdatedThreads', ()=> {
    it('groups the threads correctly by account id, with their snooze and inbox categories', ()=> {
      spyOn(CategoryStore, 'getInboxCategory').andCallFake(accId => this.inboxCatsByAccount[accId])

      waitsForPromise(()=> {
        return this.store.groupUpdatedThreads(this.threads, this.snoozeCatsByAccount)
        .then((result)=> {
          expect(result['123']).toEqual({
            threads: [this.threads[0], this.threads[1]],
            snoozeCategoryId: 'sn-1',
            returnCategoryId: 'in-1',
          })
          expect(result['321']).toEqual({
            threads: [this.threads[2]],
            snoozeCategoryId: 'sn-2',
            returnCategoryId: 'in-2',
          })
        })
      })
    });
  });

  describe('onSnoozeThreads', ()=> {
    it('auths plugin against all present accounts', ()=> {
      waitsForPromise(()=> {
        return this.store.onSnoozeThreads(this.threads, 'date', 'label')
        .then(()=> {
          expect(NylasAPI.authPlugin).toHaveBeenCalled()
          expect(NylasAPI.authPlugin.calls[0].args[2]).toEqual(this.accounts[0])
          expect(NylasAPI.authPlugin.calls[1].args[2]).toEqual(this.accounts[1])
        })
      })
    });

    it('calls Actions.setMetadata with the correct metadata', ()=> {
      waitsForPromise(()=> {
        return this.store.onSnoozeThreads(this.threads, 'date', 'label')
        .then(()=> {
          expect(Actions.setMetadata).toHaveBeenCalled()
          expect(Actions.setMetadata.calls[0].args).toEqual([
            this.updatedThreadsByAccountId['123'].threads,
            'plug-id',
            {
              snoozeDate: 'date',
              snoozeCategoryId: 'sn-1',
              returnCategoryId: 'in-1',
            },
          ])
          expect(Actions.setMetadata.calls[1].args).toEqual([
            this.updatedThreadsByAccountId['321'].threads,
            'plug-id',
            {
              snoozeDate: 'date',
              snoozeCategoryId: 'sn-2',
              returnCategoryId: 'in-2',
            },
          ])
        })
      })
    });

    it('displays dialog on error', ()=> {
      jasmine.unspy(SnoozeUtils, 'moveThreadsToSnooze')
      spyOn(SnoozeUtils, 'moveThreadsToSnooze').andReturn(Promise.reject(new Error('Oh no!')))

      waitsForPromise(()=> {
        return this.store.onSnoozeThreads(this.threads, 'date', 'label')
        .finally(()=> {
          expect(SnoozeUtils.moveThreadsFromSnooze).toHaveBeenCalled()
          expect(NylasEnv.reportError).toHaveBeenCalled()
          expect(NylasEnv.showErrorDialog).toHaveBeenCalled()
        })
      })
    });
  });
})
