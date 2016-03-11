import {
  Message,
  NylasAPI,
  Actions,
  DatabaseStore,
} from 'nylas-exports'
import SendLaterStore from '../lib/send-later-store'


describe('SendLaterStore', ()=> {
  beforeEach(()=> {
    this.store = new SendLaterStore('plug-id', 'plug-name')
  });

  describe('setMetadata', ()=> {
    beforeEach(()=> {
      this.message = new Message({accountId: 123, clientId: 'c-1'})
      this.metadata = {sendLaterDate: 'the future'}
      spyOn(this.store, 'recordAction')
      spyOn(DatabaseStore, 'modelify').andReturn(Promise.resolve([this.message]))
      spyOn(NylasAPI, 'authPlugin').andReturn(Promise.resolve())
      spyOn(Actions, 'setMetadata')
      spyOn(NylasEnv, 'reportError')
      spyOn(NylasEnv, 'showErrorDialog')
    });

    it('auths the plugin correctly', ()=> {
      waitsForPromise(()=> {
        return this.store.setMetadata('c-1', this.metadata)
        .then(()=> {
          expect(NylasAPI.authPlugin).toHaveBeenCalled()
          expect(NylasAPI.authPlugin).toHaveBeenCalledWith(
            'plug-id',
            'plug-name',
            123
          )
        })
      })
    });

    it('sets the correct metadata', ()=> {
      waitsForPromise(()=> {
        return this.store.setMetadata('c-1', this.metadata)
        .then(()=> {
          expect(Actions.setMetadata).toHaveBeenCalledWith(
            [this.message],
            'plug-id',
            this.metadata
          )
          expect(NylasEnv.reportError).not.toHaveBeenCalled()
        })
      })
    });

    it('displays dialog if an error occurs', ()=> {
      jasmine.unspy(NylasAPI, 'authPlugin')
      spyOn(NylasAPI, 'authPlugin').andReturn(Promise.reject(new Error('Oh no!')))
      waitsForPromise(()=> {
        return this.store.setMetadata('c-1', this.metadata)
        .finally(()=> {
          expect(Actions.setMetadata).not.toHaveBeenCalled()
          expect(NylasEnv.reportError).toHaveBeenCalled()
          expect(NylasEnv.showErrorDialog).toHaveBeenCalled()
        })
      })
    });
  });
});
