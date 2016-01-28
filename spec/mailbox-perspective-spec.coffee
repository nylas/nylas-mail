{AccountStore, MailboxPerspective, Category} = require 'nylas-exports'


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
