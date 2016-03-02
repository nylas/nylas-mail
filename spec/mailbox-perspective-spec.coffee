{AccountStore,
 MailboxPerspective,
 TaskFactory,
 Category,
 Thread,
 Actions,
 DatabaseStore} = require 'nylas-exports'


describe 'MailboxPerspective', ->
  beforeEach ->
    spyOn(AccountStore, 'accountForId').andReturn(AccountStore.accounts()[0])
    @accountIds = ['a1', 'a2', 'a3']
    @perspective = new MailboxPerspective(@accountIds)

  describe 'isEqual', ->
    # TODO

  describe 'canReceiveThreads', ->

    it 'returns true if the thread account ids are included in the current account ids', ->
      expect(@perspective.canReceiveThreads(['a1'])).toBe true

    it 'returns false otherwise', ->
      expect(@perspective.canReceiveThreads(['a4'])).toBe false
      expect(@perspective.canReceiveThreads([])).toBe false
      expect(@perspective.canReceiveThreads()).toBe false

  describe 'CategoriesMailboxPerspective', ->
    beforeEach ->
      @accountIds = ['a1', 'a2']
      @categories = [
        new Category(displayName: 'c1', accountId: 'a1')
        new Category(displayName: 'c2', accountId: 'a2')
        new Category(displayName: 'c3', accountId: 'a2')
      ]
      @perspective = MailboxPerspective.forCategories(@categories)

    describe 'canReceiveThreads', ->
      it 'returns true if the thread account ids are included in the current account ids', ->
        expect(@perspective.canReceiveThreads(['a2'])).toBe true

      it 'returns false otherwise', ->
        expect(@perspective.canReceiveThreads(['a4'])).toBe false
        expect(@perspective.canReceiveThreads([])).toBe false
        expect(@perspective.canReceiveThreads()).toBe false

      it 'returns false if it is not a locked category', ->
        @perspective._categories.push(
          new Category(name: 'sent', displayName: 'c4', accountId: 'a1')
        )
        expect(@perspective.canReceiveThreads(['a2'])).toBe false

    describe 'categoriesSharedName', ->
      it "returns the name if all the categories on the perspective have the same name", ->
        expect(MailboxPerspective.forCategories([
          new Category(name: 'c1', accountId: 'a1')
          new Category(name: 'c1', accountId: 'a2')
        ]).categoriesSharedName()).toEqual('c1')

      it "returns null if there are no categories", ->
        expect(MailboxPerspective.forStarred(['a1', 'a2']).categoriesSharedName()).toEqual(null)

      it "returns null if the categories have different names", ->
        expect(MailboxPerspective.forCategories([
          new Category(name: 'c1', accountId: 'a1')
          new Category(name: 'c2', accountId: 'a2')
        ]).categoriesSharedName()).toEqual(null)

    describe 'receiveThreads', ->
      # TODO

    describe 'removeThreads', ->
      beforeEach ->
        @threads = [new Thread(id:'t1'), new Thread(id: 't2')]
        spyOn(Actions, 'queueTasks')
        spyOn(DatabaseStore, 'modelify').andReturn then: (cb) => cb(@threads)

      it 'moves the threads to finished category if in inbox', ->
        spyOn(TaskFactory, 'tasksForRemovingCategories')
        @categories = [
          new Category(name: 'inbox', accountId: 'a1')
          new Category(name: 'inbox', accountId: 'a2')
          new Category(name: 'inbox', accountId: 'a2')
        ]
        @perspective = MailboxPerspective.forCategories(@categories)
        @perspective.removeThreads(@threads)
        expect(TaskFactory.tasksForRemovingCategories).toHaveBeenCalledWith({
          threads: @threads,
          moveToFinishedCategory: true,
          categories: @categories
        })

      it 'moves threads to inbox if in trash', ->
        spyOn(TaskFactory, 'tasksForMovingToInbox')
        @categories = [
          new Category(name: 'trash', accountId: 'a1')
          new Category(name: 'trash', accountId: 'a2')
          new Category(name: 'trash', accountId: 'a2')
        ]
        @perspective = MailboxPerspective.forCategories(@categories)
        @perspective.removeThreads(@threads)
        expect(TaskFactory.tasksForMovingToInbox).toHaveBeenCalledWith({
          threads: @threads,
          fromPerspective: @perspective
        })

      it 'removes categories if the current perspective does not correspond to archive or sent', ->
        spyOn(TaskFactory, 'tasksForRemovingCategories')
        @categories = [
          new Category(displayName: 'c1', accountId: 'a1')
          new Category(displayName: 'c2', accountId: 'a2')
          new Category(displayName: 'c3', accountId: 'a2')
        ]
        @perspective = MailboxPerspective.forCategories(@categories)
        @perspective.removeThreads(@threads)
        expect(TaskFactory.tasksForRemovingCategories).toHaveBeenCalledWith({
          threads: @threads,
          moveToFinishedCategory: false,
          categories: @categories
        })
