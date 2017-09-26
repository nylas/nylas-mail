import {
  TaskFactory,
  AccountStore,
  CategoryStore,
  Label,
  Thread,
  ChangeFolderTask,
  ChangeLabelsTask,
} from 'mailspring-exports';

describe('TaskFactory', function taskFactory() {
  beforeEach(() => {
    this.categories = {
      'ac-1': {
        archive: new Label({ name: 'archive' }),
        inbox: new Label({ name: 'inbox1' }),
        trash: new Label({ name: 'trash1' }),
      },
      'ac-2': {
        archive: new Label({ name: 'all' }),
        inbox: new Label({ name: 'inbox2' }),
        trash: new Label({ name: 'trash2' }),
      },
    };
    this.accounts = {
      'ac-1': {
        id: 'ac-1',
        usesFolders: () => true,
        preferredRemovalDestination: () => this.categories['ac-1'].archive,
      },
      'ac-2': {
        id: 'ac-2',
        usesFolders: () => false,
        preferredRemovalDestination: () => this.categories['ac-2'].trash,
      },
    };
    this.threads = [new Thread({ accountId: 'ac-1' }), new Thread({ accountId: 'ac-2' })];

    spyOn(CategoryStore, 'getArchiveCategory').andCallFake(acc => {
      return this.categories[acc.id].archive;
    });
    spyOn(CategoryStore, 'getInboxCategory').andCallFake(acc => {
      return this.categories[acc.id].inbox;
    });
    spyOn(CategoryStore, 'getTrashCategory').andCallFake(acc => {
      return this.categories[acc.id].trash;
    });
    spyOn(AccountStore, 'accountForId').andCallFake(accId => {
      return this.accounts[accId];
    });
  });

  // todo bg
  xdescribe('tasksForApplyingCategories', () => {
    it('creates the correct tasks', () => {
      const categoriesToRemove = accId => {
        if (accId === 'ac-1') {
          return [new Label({ displayName: 'folder1', accountId: 'ac-1' })];
        }
        return [new Label({ displayName: 'label2', accountId: 'ac-2' })];
      };
      const categoriesToAdd = accId => [this.categories[accId].inbox];
      const taskDescription = 'dope';

      const tasks = TaskFactory.tasksForApplyingCategories({
        threads: this.threads,
        categoriesToAdd,
        categoriesToRemove,
        taskDescription,
      });

      expect(tasks.length).toEqual(2);
      const taskExchange = tasks[0];
      const taskGmail = tasks[1];

      expect(taskExchange instanceof ChangeFolderTask).toBe(true);
      expect(taskExchange.folder.name).toEqual('inbox1');
      expect(taskExchange.taskDescription).toEqual(taskDescription);

      expect(taskGmail instanceof ChangeLabelsTask).toBe(true);
      expect(taskGmail.labelsToAdd.length).toEqual(1);
      expect(taskGmail.labelsToAdd[0].name).toEqual('inbox2');
      expect(taskGmail.labelsToRemove.length).toEqual(1);
      expect(taskGmail.labelsToRemove[0].displayName).toEqual('label2');
      expect(taskGmail.taskDescription).toEqual(taskDescription);
    });

    it('throws if threads are not instances of Thread', () => {
      const threads = [{ accountId: 'ac-1' }, { accountId: 'ac-2' }];
      expect(() => {
        TaskFactory.tasksForApplyingCategories({ threads });
      }).toThrow();
    });

    it('throws if categoriesToAdd does not return an array', () => {
      expect(() => {
        TaskFactory.tasksForApplyingCategories({
          threads: this.threads,
          categoriesToAdd: { displayName: 'cat1' },
        });
      }).toThrow();
    });

    it('throws if categoriesToAdd does not return an array', () => {
      expect(() => {
        TaskFactory.tasksForApplyingCategories({
          threads: this.threads,
          categoriesToRemove: { displayName: 'cat1' },
        });
      }).toThrow();
    });

    it('does not create folder tasks if categoriesToAdd not present', () => {
      const categoriesToRemove = accId => {
        if (accId === 'ac-1') {
          return [new Label({ displayName: 'folder1', accountId: 'ac-1' })];
        }
        return [new Label({ displayName: 'label2', accountId: 'ac-2' })];
      };
      const taskDescription = 'dope';

      const tasks = TaskFactory.tasksForApplyingCategories({
        threads: this.threads,
        categoriesToRemove,
        taskDescription,
      });
      expect(tasks.length).toEqual(1);
      const taskGmail = tasks[0];
      expect(taskGmail instanceof ChangeLabelsTask).toBe(true);
      expect(taskGmail.labelsToRemove.length).toEqual(1);
    });

    it('does not create label tasks if both categoriesToAdd and categoriesToRemove return empty', () => {
      const categoriesToAdd = accId => {
        return accId === 'ac-1' ? [this.categories[accId].inbox] : [];
      };
      const taskDescription = 'dope';

      const tasks = TaskFactory.tasksForApplyingCategories({
        threads: this.threads,
        categoriesToAdd,
        taskDescription,
      });
      expect(tasks.length).toEqual(1);
      const taskExchange = tasks[0];

      expect(taskExchange instanceof ChangeFolderTask).toBe(true);
      expect(taskExchange.folder.name).toEqual('inbox1');
    });

    describe('exchange accounts', () => {
      it('throws if folder is not a category', () => {
        expect(() => {
          TaskFactory.tasksForApplyingCategories({
            threads: this.threads,
            categoriesToAdd: () => [{ accountId: 'ac-1', name: 'inbox' }],
          });
        }).toThrow();
      });

      it('throws if attempting to add more than one folder', () => {
        expect(() => {
          TaskFactory.tasksForApplyingCategories({
            threads: this.threads,
            categoriesToAdd: () => [{ accountId: 'ac-1', name: 'inbox' }, {}],
          });
        }).toThrow();
      });
    });
  });

  describe('taskForInvertingUnread', () => {});

  describe('taskForInvertingStarred', () => {});
});
