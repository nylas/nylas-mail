import {
  AccountStore,
  MailboxPerspective,
  TaskFactory,
  Category,
  CategoryStore,
} from 'nylas-exports'

import CategoryRemovalTargetRulesets from '../internal_packages/thread-list/lib/category-removal-target-rulesets'

const {Default} = CategoryRemovalTargetRulesets;


describe('MailboxPerspective', function mailboxPerspective() {
  beforeEach(() => {
    this.accountIds = ['a1', 'a2']
    this.accounts = {
      a1: {
        id: 'a1',
        defaultFinishedCategory: () => ({displayName: 'archive'}),
        categoryIcon: () => null,
      },
      a2: {
        id: 'a2',
        defaultFinishedCategory: () => ({displayName: 'trash2'}),
        categoryIcon: () => null,
      },
    }
    this.perspective = new MailboxPerspective(this.accountIds)
    spyOn(AccountStore, 'accountForId').andCallFake((accId) => this.accounts[accId])
  });

  describe('isEqual', () => {
    // TODO
  });

  describe('canArchiveThreads', () => {
    it('returns false if the perspective is archive', () => {
      const accounts = [
        {canArchiveThreads: () => true},
        {canArchiveThreads: () => true},
      ]
      spyOn(AccountStore, 'accountsForItems').andReturn(accounts)
      spyOn(this.perspective, 'isArchive').andReturn(true)
      expect(this.perspective.canArchiveThreads()).toBe(false)
    });

    it('returns false if one of the accounts associated with the threads cannot archive', () => {
      const accounts = [
        {canArchiveThreads: () => true},
        {canArchiveThreads: () => false},
      ]
      spyOn(AccountStore, 'accountsForItems').andReturn(accounts)
      spyOn(this.perspective, 'isArchive').andReturn(false)
      expect(this.perspective.canArchiveThreads()).toBe(false)
    });

    it('returns true otherwise', () => {
      const accounts = [
        {canArchiveThreads: () => true},
        {canArchiveThreads: () => true},
      ]
      spyOn(AccountStore, 'accountsForItems').andReturn(accounts)
      spyOn(this.perspective, 'isArchive').andReturn(false)
      expect(this.perspective.canArchiveThreads()).toBe(true)
    });
  });

  describe('canMoveThreadsTo', () => {
    it('returns false if the perspective is the target folder', () => {
      const accounts = [
        {id: 'a'},
        {id: 'b'},
      ]
      spyOn(AccountStore, 'accountsForItems').andReturn(accounts)
      spyOn(this.perspective, 'categoriesSharedName').andReturn('trash')
      expect(this.perspective.canMoveThreadsTo([], 'trash')).toBe(false)
    });

    it('returns false if one of the accounts associated with the threads does not have the folder', () => {
      const accounts = [
        {id: 'a'},
        {id: 'b'},
      ]
      spyOn(CategoryStore, 'getStandardCategory').andReturn(null)
      spyOn(AccountStore, 'accountsForItems').andReturn(accounts)
      spyOn(this.perspective, 'categoriesSharedName').andReturn('inbox')
      expect(this.perspective.canMoveThreadsTo([], 'trash')).toBe(false)
    });

    it('returns true otherwise', () => {
      const accounts = [
        {id: 'a'},
        {id: 'b'},
      ]
      const category = {id: 'cat'};
      spyOn(CategoryStore, 'getStandardCategory').andReturn(category)
      spyOn(AccountStore, 'accountsForItems').andReturn(accounts)
      spyOn(this.perspective, 'categoriesSharedName').andReturn('inbox')
      expect(this.perspective.canMoveThreadsTo([], 'trash')).toBe(true)
    });
  });

  describe('canReceiveThreadsFromAccountIds', () => {
    it('returns true if the thread account ids are included in the current account ids', () => {
      expect(this.perspective.canReceiveThreadsFromAccountIds(['a1'])).toBe(true)
    });

    it('returns false otherwise', () => {
      expect(this.perspective.canReceiveThreadsFromAccountIds(['a4'])).toBe(false)
      expect(this.perspective.canReceiveThreadsFromAccountIds([])).toBe(false)
      expect(this.perspective.canReceiveThreadsFromAccountIds()).toBe(false)
    });
  });

  describe('tasksForRemovingItems', () => {
    beforeEach(() => {
      this.categories = {
        a1: {
          archive: new Category({name: 'archive', displayName: 'archive', accountId: 'a1'}),
          inbox: new Category({name: 'inbox', displayName: 'inbox1', accountId: 'a1'}),
          trash: new Category({name: 'trash', displayName: 'trash1', accountId: 'a1'}),
          category: new Category({name: null, displayName: 'folder1', accountId: 'a1'}),
        },
        a2: {
          archive: new Category({name: 'all', displayName: 'all', accountId: 'a2'}),
          inbox: new Category({name: 'inbox', displayName: 'inbox2', accountId: 'a2'}),
          trash: new Category({name: 'trash', displayName: 'trash2', accountId: 'a2'}),
          category: new Category({name: null, displayName: 'label2', accountId: 'a2'}),
        },
      }
      this.threads = [
        {accountId: 'a1'},
        {accountId: 'a2'},
      ]
      spyOn(TaskFactory, 'tasksForApplyingCategories')
      spyOn(CategoryStore, 'getTrashCategory').andCallFake((accId) => {
        return this.categories[accId].trash
      })
    });

    function assertMoved(accId) {
      expect(TaskFactory.tasksForApplyingCategories).toHaveBeenCalled()
      const {args} = TaskFactory.tasksForApplyingCategories.calls[0]
      const {categoriesToRemove, categoriesToAdd} = args[0]

      const assertor = {
        from(originName) {
          expect(categoriesToRemove(accId)[0].displayName).toEqual(originName)
          return assertor
        },
        to(destinationName) {
          expect(categoriesToAdd(accId)[0].displayName).toEqual(destinationName)
          return assertor
        },
      }
      return assertor
    }

    it('moves to finished category if viewing inbox', () => {
      const perspective = MailboxPerspective.forCategories([
        this.categories.a1.inbox,
        this.categories.a2.inbox,
      ])
      perspective.tasksForRemovingItems(this.threads, Default)
      assertMoved('a1').from('inbox1').to('archive')
      assertMoved('a2').from('inbox2').to('trash2')
    });

    it('moves to trash if viewing archive', () => {
      const perspective = MailboxPerspective.forCategories([
        this.categories.a1.archive,
        this.categories.a2.archive,
      ])
      perspective.tasksForRemovingItems(this.threads, Default)
      assertMoved('a1').from('archive').to('trash1')
      assertMoved('a2').from('all').to('trash2')
    })

    it('deletes permanently if viewing trash', () => {
      // TODO
      // Not currently possible
    });

    it('moves to default finished category if viewing category', () => {
      const perspective = MailboxPerspective.forCategories([
        this.categories.a1.category,
        this.categories.a2.category,
      ])
      perspective.tasksForRemovingItems(this.threads, Default)
      assertMoved('a1').from('folder1').to('archive')
      assertMoved('a2').from('label2').to('trash2')
    })

    it('unstars if viewing starred', () => {
      spyOn(TaskFactory, 'taskForInvertingStarred').andReturn({some: 'task'})
      const perspective = MailboxPerspective.forStarred(this.accountIds)
      const tasks = perspective.tasksForRemovingItems(this.threads, Default)
      expect(tasks).toEqual([{some: 'task'}])
    });

    it('does nothing when viewing spam or sent', () => {
      ['spam', 'sent'].forEach((invalid) => {
        const perspective = MailboxPerspective.forCategories([
          new Category({name: invalid, accountId: 'a1'}),
          new Category({name: invalid, accountId: 'a2'}),
        ])
        const tasks = perspective.tasksForRemovingItems(this.threads, Default)
        expect(TaskFactory.tasksForApplyingCategories).not.toHaveBeenCalled()
        expect(tasks).toEqual([])
      })
    });

    describe('when perspective is category perspective', () => {
      it('overrides default ruleset', () => {
        const customRuleset = {
          all: () => ({displayName: 'my category'}),
        }
        const perspective = MailboxPerspective.forCategories([
          this.categories.a1.category,
        ])
        spyOn(perspective, 'categoriesSharedName').andReturn('all')
        perspective.tasksForRemovingItems(this.threads, customRuleset)
        assertMoved('a1').to('my category')
      });

      it('does not create tasks if any name in the ruleset is null', () => {
        const customRuleset = {
          all: null,
        }
        const perspective = MailboxPerspective.forCategories([
          this.categories.a1.category,
        ])
        spyOn(perspective, 'categoriesSharedName').andReturn('all')
        const tasks = perspective.tasksForRemovingItems(this.threads, customRuleset)
        expect(tasks).toEqual([])
      });
    });
  });

  describe('CategoryMailboxPerspective', () => {
    beforeEach(() => {
      this.categories = [
        new Category({displayName: 'c1', accountId: 'a1'}),
        new Category({displayName: 'c2', accountId: 'a2'}),
        new Category({displayName: 'c3', accountId: 'a2'}),
      ]
      this.perspective = MailboxPerspective.forCategories(this.categories)
    });

    describe('canReceiveThreadsFromAccountIds', () => {
      it('returns true if the thread account ids are included in the current account ids', () => {
        expect(this.perspective.canReceiveThreadsFromAccountIds(['a1'])).toBe(true)
      });

      it('returns false otherwise', () => {
        expect(this.perspective.canReceiveThreadsFromAccountIds(['a4'])).toBe(false)
        expect(this.perspective.canReceiveThreadsFromAccountIds([])).toBe(false)
        expect(this.perspective.canReceiveThreadsFromAccountIds()).toBe(false)
      });

      it('returns false if it is a locked category', () => {
        this.perspective._categories.push(
          new Category({name: 'sent', displayName: 'c4', accountId: 'a1'})
        )
        expect(this.perspective.canReceiveThreadsFromAccountIds(['a2'])).toBe(false)
      });
    });

    describe('receiveThreads', () => {
      // TODO
    });
  });
});
