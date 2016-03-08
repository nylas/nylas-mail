import moment from 'moment'
import {
  Actions,
  TaskQueueStatusStore,
  TaskFactory,
  DatabaseStore,
  Category,
  Thread,
  CategoryStore,
} from 'nylas-exports'
import SnoozeUtils from '../lib/snooze-utils'

const {
  snoozedUntilMessage,
  createSnoozeCategory,
  getSnoozeCategory,
  moveThreads,
} = SnoozeUtils


describe('Snooze Utils', ()=> {
  beforeEach(()=> {
    this.name = 'Snoozed Folder'
    this.accId = 123
    spyOn(SnoozeUtils, 'whenCategoriesReady').andReturn(Promise.resolve())
  })

  describe('snoozedUntilMessage', ()=> {
    it('returns correct message if no snooze date provided', ()=> {
      expect(snoozedUntilMessage()).toEqual('Snoozed')
    });

    describe('when less than 24 hours from now', ()=> {
      it('returns correct message if snoozeDate is on the hour of the clock', ()=> {
        const now9AM = moment().hour(9).minute(0)
        const tomorrowAt8 = moment(now9AM).add(1, 'day').hour(8)
        const result = snoozedUntilMessage(tomorrowAt8, now9AM)
        expect(result).toEqual('Snoozed until 8 AM')
      });

      it('returns correct message if snoozeDate otherwise', ()=> {
        const now9AM = moment().hour(9).minute(0)
        const snooze10AM = moment(now9AM).hour(10).minute(5)
        const result = snoozedUntilMessage(snooze10AM, now9AM)
        expect(result).toEqual('Snoozed until 10:05 AM')
      });
    });

    describe('when more than 24 hourse from now', ()=> {
      it('returns correct message if snoozeDate is on the hour of the clock', ()=> {
        // Jan 1
        const now9AM = moment().month(0).date(1).hour(9).minute(0)
        const tomorrowAt10 = moment(now9AM).add(1, 'day').hour(10)
        const result = snoozedUntilMessage(tomorrowAt10, now9AM)
        expect(result).toEqual('Snoozed until Jan 2, 10 AM')
      });

      it('returns correct message if snoozeDate otherwise', ()=> {
        // Jan 1
        const now9AM = moment().month(0).date(1).hour(9).minute(0)
        const tomorrowAt930 = moment(now9AM).add(1, 'day').minute(30)
        const result = snoozedUntilMessage(tomorrowAt930, now9AM)
        expect(result).toEqual('Snoozed until Jan 2, 9:30 AM')
      });
    });
  });

  describe('createSnoozeCategory', ()=> {
    beforeEach(()=> {
      this.category = new Category({
        displayName: this.name,
        accountId: this.accId,
        clientId: 321,
        serverId: 321,
      })
      spyOn(Actions, 'queueTask')
      spyOn(TaskQueueStatusStore, 'waitForPerformRemote').andReturn(Promise.resolve())
      spyOn(DatabaseStore, 'findBy').andReturn(Promise.resolve(this.category))
    })

    it('creates category with correct snooze name', ()=> {
      createSnoozeCategory(this.accId, this.name)
      expect(Actions.queueTask).toHaveBeenCalled()
      const task = Actions.queueTask.calls[0].args[0]
      expect(task.category.displayName).toEqual(this.name)
      expect(task.category.accountId).toEqual(this.accId)
    });

    it('resolves with the updated category that has been saved to the server', ()=> {
      waitsForPromise(()=> {
        return createSnoozeCategory(this.accId, this.name).then((result)=> {
          expect(DatabaseStore.findBy).toHaveBeenCalled()
          expect(result).toBe(this.category)
        })
      })
    });

    it('rejects if the category could not be found in the database', ()=> {
      this.category.serverId = null
      jasmine.unspy(DatabaseStore, 'findBy')
      spyOn(DatabaseStore, 'findBy').andReturn(Promise.resolve(this.category))
      waitsForPromise(()=> {
        return createSnoozeCategory(this.accId, this.name)
        .then(()=> {
          throw new Error('createSnoozeCategory should not resolve in this case!')
        })
        .catch((error)=> {
          expect(DatabaseStore.findBy).toHaveBeenCalled()
          expect(error.message).toEqual('Could not create Snooze category')
        })
      })
    });

    it('rejects if the category could not be saved to the server', ()=> {
      jasmine.unspy(DatabaseStore, 'findBy')
      spyOn(DatabaseStore, 'findBy').andReturn(Promise.resolve(undefined))
      waitsForPromise(()=> {
        return createSnoozeCategory(this.accId, this.name)
        .then(()=> {
          throw new Error('createSnoozeCategory should not resolve in this case!')
        })
        .catch((error)=> {
          expect(DatabaseStore.findBy).toHaveBeenCalled()
          expect(error.message).toEqual('Could not create Snooze category')
        })
      })
    });
  });

  describe('getSnoozeCategory', ()=> {
    it('resolves category if it exists in the category store', ()=> {
      const categories = [
        new Category({accountId: this.accId, name: 'inbox'}),
        new Category({accountId: this.accId, displayName: this.name}),
      ]
      spyOn(CategoryStore, 'categories').andReturn(categories)
      spyOn(SnoozeUtils, 'createSnoozeCategory')

      waitsForPromise(()=> {
        return getSnoozeCategory(this.accountId, this.name)
        .then((result)=> {
          expect(SnoozeUtils.createSnoozeCategory).not.toHaveBeenCalled()
          expect(result).toBe(categories[1])
        })
      })
    });

    it('creates category if it does not exist', ()=> {
      const categories = [
        new Category({accountId: this.accId, name: 'inbox'}),
      ]
      const snoozeCat = new Category({accountId: this.accId, displayName: this.name})
      spyOn(CategoryStore, 'categories').andReturn(categories)
      spyOn(SnoozeUtils, 'createSnoozeCategory').andReturn(Promise.resolve(snoozeCat))

      waitsForPromise(()=> {
        return getSnoozeCategory(this.accId, this.name)
        .then((result)=> {
          expect(SnoozeUtils.createSnoozeCategory).toHaveBeenCalledWith(this.accId, this.name)
          expect(result).toBe(snoozeCat)
        })
      })
    });
  });

  describe('moveThreads', ()=> {
    beforeEach(()=> {
      this.description = 'Snoozin';
      this.snoozeCatsByAccount = {
        '123': new Category({accountId: 123, displayName: this.name, serverId: 'sr-1'}),
        '321': new Category({accountId: 321, displayName: this.name, serverId: 'sr-2'}),
      }
      this.inboxCatsByAccount = {
        '123': new Category({accountId: 123, name: 'inbox', serverId: 'sr-3'}),
        '321': new Category({accountId: 321, name: 'inbox', serverId: 'sr-4'}),
      }
      this.threads = [
        new Thread({accountId: 123}),
        new Thread({accountId: 123}),
        new Thread({accountId: 321}),
      ]
      this.getInboxCat = (accId) => [this.inboxCatsByAccount[accId]]
      this.getSnoozeCat = (accId) => [this.snoozeCatsByAccount[accId]]

      spyOn(DatabaseStore, 'modelify').andReturn(Promise.resolve(this.threads))
      spyOn(TaskFactory, 'tasksForApplyingCategories').andReturn([])
      spyOn(TaskQueueStatusStore, 'waitForPerformRemote').andReturn(Promise.resolve())
      spyOn(Actions, 'queueTasks')
    })

    it('creates the tasks to move threads correctly when snoozing', ()=> {
      const snooze = true
      const description = this.description

      waitsForPromise(()=> {
        return moveThreads(this.threads, {snooze, description, getInboxCategory: this.getInboxCat, getSnoozeCategory: this.getSnoozeCat})
        .then(()=> {
          expect(TaskFactory.tasksForApplyingCategories).toHaveBeenCalled()
          expect(Actions.queueTasks).toHaveBeenCalled()
          const {threads, categoriesToAdd, categoriesToRemove, taskDescription} = TaskFactory.tasksForApplyingCategories.calls[0].args[0]
          expect(threads).toBe(this.threads)
          expect(categoriesToRemove('123')[0]).toBe(this.inboxCatsByAccount['123'])
          expect(categoriesToRemove('321')[0]).toBe(this.inboxCatsByAccount['321'])
          expect(categoriesToAdd('123')[0]).toBe(this.snoozeCatsByAccount['123'])
          expect(categoriesToAdd('321')[0]).toBe(this.snoozeCatsByAccount['321'])
          expect(taskDescription).toEqual(description)
        })
      })
    });

    it('creates the tasks to move threads correctly when unsnoozing', ()=> {
      const snooze = false
      const description = this.description

      waitsForPromise(()=> {
        return moveThreads(this.threads, {snooze, description, getInboxCategory: this.getInboxCat, getSnoozeCategory: this.getSnoozeCat})
        .then(()=> {
          expect(TaskFactory.tasksForApplyingCategories).toHaveBeenCalled()
          expect(Actions.queueTasks).toHaveBeenCalled()
          const {threads, categoriesToAdd, categoriesToRemove, taskDescription} = TaskFactory.tasksForApplyingCategories.calls[0].args[0]
          expect(threads).toBe(this.threads)
          expect(categoriesToAdd('123')[0]).toBe(this.inboxCatsByAccount['123'])
          expect(categoriesToAdd('321')[0]).toBe(this.inboxCatsByAccount['321'])
          expect(categoriesToRemove('123')[0]).toBe(this.snoozeCatsByAccount['123'])
          expect(categoriesToRemove('321')[0]).toBe(this.snoozeCatsByAccount['321'])
          expect(taskDescription).toEqual(description)
        })
      })
    });
  });
});
