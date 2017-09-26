import moment from 'moment';
import {
  Actions,
  TaskQueue,
  TaskFactory,
  DatabaseStore,
  Folder,
  Thread,
  FolderSyncProgressStore,
} from 'mailspring-exports';
import * as SnoozeUtils from '../lib/snooze-utils';

xdescribe('Snooze Utils', function snoozeUtils() {
  beforeEach(() => {
    this.name = 'Snoozed Folder';
    this.accId = 123;
    spyOn(FolderSyncProgressStore, 'whenCategoryListSynced').andReturn(Promise.resolve());
  });

  describe('snoozedUntilMessage', () => {
    it('returns correct message if no snooze date provided', () => {
      expect(SnoozeUtils.snoozedUntilMessage()).toEqual('Snoozed');
    });

    describe('when less than 24 hours from now', () => {
      it('returns correct message if snoozeDate is on the hour of the clock', () => {
        const now9AM = window
          .testNowMoment()
          .hour(9)
          .minute(0);
        const tomorrowAt8 = moment(now9AM)
          .add(1, 'day')
          .hour(8);
        const result = SnoozeUtils.snoozedUntilMessage(tomorrowAt8, now9AM);
        expect(result).toEqual('Snoozed until 8 AM');
      });

      it('returns correct message if snoozeDate otherwise', () => {
        const now9AM = window
          .testNowMoment()
          .hour(9)
          .minute(0);
        const snooze10AM = moment(now9AM)
          .hour(10)
          .minute(5);
        const result = SnoozeUtils.snoozedUntilMessage(snooze10AM, now9AM);
        expect(result).toEqual('Snoozed until 10:05 AM');
      });
    });

    describe('when more than 24 hourse from now', () => {
      it('returns correct message if snoozeDate is on the hour of the clock', () => {
        // Jan 1
        const now9AM = window
          .testNowMoment()
          .month(0)
          .date(1)
          .hour(9)
          .minute(0);
        const tomorrowAt10 = moment(now9AM)
          .add(1, 'day')
          .hour(10);
        const result = SnoozeUtils.snoozedUntilMessage(tomorrowAt10, now9AM);
        expect(result).toEqual('Snoozed until Jan 2, 10 AM');
      });

      it('returns correct message if snoozeDate otherwise', () => {
        // Jan 1
        const now9AM = window
          .testNowMoment()
          .month(0)
          .date(1)
          .hour(9)
          .minute(0);
        const tomorrowAt930 = moment(now9AM)
          .add(1, 'day')
          .minute(30);
        const result = SnoozeUtils.snoozedUntilMessage(tomorrowAt930, now9AM);
        expect(result).toEqual('Snoozed until Jan 2, 9:30 AM');
      });
    });
  });

  describe('moveThreads', () => {
    beforeEach(() => {
      this.description = 'Snoozin';
      this.snoozeCatsByAccount = {
        123: new Folder({ accountId: 123, displayName: this.name, id: 'sr-1' }),
        321: new Folder({ accountId: 321, displayName: this.name, id: 'sr-2' }),
      };
      this.inboxCatsByAccount = {
        123: new Folder({ accountId: 123, name: 'inbox', id: 'sr-3' }),
        321: new Folder({ accountId: 321, name: 'inbox', id: 'sr-4' }),
      };
      this.threads = [
        new Thread({ accountId: 123 }),
        new Thread({ accountId: 123 }),
        new Thread({ accountId: 321 }),
      ];
      this.getInboxCat = accId => [this.inboxCatsByAccount[accId]];
      this.getSnoozeCat = accId => [this.snoozeCatsByAccount[accId]];

      spyOn(DatabaseStore, 'modelify').andReturn(Promise.resolve(this.threads));
      spyOn(TaskFactory, 'tasksForApplyingCategories').andReturn([]);
      spyOn(TaskQueue, 'waitForPerformRemote').andReturn(Promise.resolve());
      spyOn(Actions, 'queueTasks');
    });

    it('creates the tasks to move threads correctly when snoozing', () => {
      const snooze = true;
      const description = this.description;

      waitsForPromise(() => {
        return SnoozeUtils.moveThreads(this.threads, {
          snooze,
          description,
          getInboxCategory: this.getInboxCat,
          getSnoozeCategory: this.getSnoozeCat,
        }).then(() => {
          expect(TaskFactory.tasksForApplyingCategories).toHaveBeenCalled();
          expect(Actions.queueTasks).toHaveBeenCalled();
          const {
            threads,
            categoriesToAdd,
            categoriesToRemove,
            taskDescription,
          } = TaskFactory.tasksForApplyingCategories.calls[0].args[0];
          expect(threads).toBe(this.threads);
          expect(categoriesToRemove('123')[0]).toBe(this.inboxCatsByAccount['123']);
          expect(categoriesToRemove('321')[0]).toBe(this.inboxCatsByAccount['321']);
          expect(categoriesToAdd('123')[0]).toBe(this.snoozeCatsByAccount['123']);
          expect(categoriesToAdd('321')[0]).toBe(this.snoozeCatsByAccount['321']);
          expect(taskDescription).toEqual(description);
        });
      });
    });

    it('creates the tasks to move threads correctly when unsnoozing', () => {
      const snooze = false;
      const description = this.description;

      waitsForPromise(() => {
        return SnoozeUtils.moveThreads(this.threads, {
          snooze,
          description,
          getInboxCategory: this.getInboxCat,
          getSnoozeCategory: this.getSnoozeCat,
        }).then(() => {
          expect(TaskFactory.tasksForApplyingCategories).toHaveBeenCalled();
          expect(Actions.queueTasks).toHaveBeenCalled();
          const {
            threads,
            categoriesToAdd,
            categoriesToRemove,
            taskDescription,
          } = TaskFactory.tasksForApplyingCategories.calls[0].args[0];
          expect(threads).toBe(this.threads);
          expect(categoriesToAdd('123')[0]).toBe(this.inboxCatsByAccount['123']);
          expect(categoriesToAdd('321')[0]).toBe(this.inboxCatsByAccount['321']);
          expect(categoriesToRemove('123')[0]).toBe(this.snoozeCatsByAccount['123']);
          expect(categoriesToRemove('321')[0]).toBe(this.snoozeCatsByAccount['321']);
          expect(taskDescription).toEqual(description);
        });
      });
    });
  });
});
