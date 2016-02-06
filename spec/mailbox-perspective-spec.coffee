{AccountStore, MailboxPerspective, TaskFactory, Category, Actions, DatabaseStore} = require 'nylas-exports'


describe 'MailboxPerspective', ->
  beforeEach ->
    spyOn(AccountStore, 'accountForId').andReturn {categoryIcon: -> 'icon'}
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

    describe 'receiveThreads', ->
      # TODO

    describe 'removeThreads', ->
      beforeEach ->
        @threads = ['t1', 't2']
        @taskArgs = {threads: @threads, categories: @categories}
        spyOn(Actions, 'queueTasks')
        spyOn(DatabaseStore, 'modelify').andReturn then: (cb) => cb(@threads)

      it 'moves the threads to finished category if in inbox', ->
        spyOn(@perspective, 'isInbox').andReturn true
        spyOn(@perspective, 'canTrashThreads').andReturn true
        spyOn(@perspective, 'canArchiveThreads').andReturn true
        spyOn(TaskFactory, 'tasksForRemovingCategories')
        @perspective.removeThreads(@threads)
        @taskArgs.moveToFinishedCategory = true
        expect(TaskFactory.tasksForRemovingCategories).toHaveBeenCalledWith(@taskArgs)

      it 'moves threads to inbox if in trash', ->
        spyOn(@perspective, 'isInbox').andReturn false
        spyOn(@perspective, 'canTrashThreads').andReturn false
        spyOn(@perspective, 'canArchiveThreads').andReturn true
        spyOn(TaskFactory, 'tasksForMovingToInbox')
        @perspective.removeThreads(@threads)
        expect(TaskFactory.tasksForMovingToInbox).toHaveBeenCalledWith({threads: @threads, fromPerspective: @perspective})

      it 'removes categories if the current perspective does not correspond to archive or sent', ->
        spyOn(@perspective, 'isInbox').andReturn false
        spyOn(@perspective, 'canTrashThreads').andReturn true
        spyOn(@perspective, 'canArchiveThreads').andReturn true
        spyOn(TaskFactory, 'tasksForRemovingCategories')
        @perspective.removeThreads(@threads)
        @taskArgs.moveToFinishedCategory = false
        expect(TaskFactory.tasksForRemovingCategories).toHaveBeenCalledWith(@taskArgs)

      it 'does nothing otherwise', ->
        spyOn(@perspective, 'isInbox').andReturn false
        spyOn(@perspective, 'canTrashThreads').andReturn true
        spyOn(@perspective, 'canArchiveThreads').andReturn false
        @perspective.removeThreads(@threads)
        expect(Actions.queueTasks).not.toHaveBeenCalled()
