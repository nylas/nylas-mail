{Folder, Label} = require 'nylas-exports'

describe 'Category', ->

  describe '.categoriesSharedRole', ->

    it 'returns the name if all the categories on the perspective have the same role', ->
      expect(Category.categoriesSharedRole([
        new Folder({path: 'c1', role: 'c1', accountId: 'a1'}),
        new Folder({path: 'c1', role: 'c1', accountId: 'a2'}),
      ])).toEqual('c1')

    it 'returns null if there are no categories', ->
      expect(Category.categoriesSharedRole([])).toEqual(null)

    it 'returns null if the categories have different roles', ->
      expect(Category.categoriesSharedRole([
        new Folder({path: 'c1', role: 'c1', accountId: 'a1'}),
        new Folder({path: 'c2', role: 'c2', accountId: 'a2'}),
      ])).toEqual(null)

  describe 'displayName', ->
    it "should strip the INBOX. prefix from FastMail folders", ->
      foo = new Folder({path: 'INBOX.Foo'})
      expect(foo.displayName).toEqual('Foo')
      foo = new Folder({path: 'INBOX'})
      expect(foo.displayName).toEqual('Inbox')

  describe 'category types', ->
    it 'assigns type correctly when it is a user category', ->
      cat = new Label
      cat.role = undefined
      expect(cat.isUserCategory()).toBe true
      expect(cat.isStandardCategory()).toBe false
      expect(cat.isHiddenCategory()).toBe false
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type correctly when it is a standard category', ->
      cat = new Label
      cat.role = 'inbox'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory()).toBe true
      expect(cat.isHiddenCategory()).toBe false
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type for `important` category when should not show important', ->
      cat = new Label
      cat.role = 'important'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory(false)).toBe false
      expect(cat.isHiddenCategory()).toBe true
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type correctly when it is a hidden category', ->
      cat = new Label
      cat.role = 'archive'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory()).toBe true
      expect(cat.isHiddenCategory()).toBe true
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type correctly when it is a locked category', ->
      cat = new Label
      cat.role = 'sent'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory()).toBe true
      expect(cat.isHiddenCategory()).toBe true
      expect(cat.isLockedCategory()).toBe true
