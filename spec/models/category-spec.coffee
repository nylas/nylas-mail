{Category, Label} = require 'nylas-exports'

describe 'Category', ->

  describe 'category types', ->

    it 'assigns type correctly when it is a user category', ->
      cat = new Label
      cat.name = undefined
      expect(cat.isUserCategory()).toBe true
      expect(cat.isStandardCategory()).toBe false
      expect(cat.isHiddenCategory()).toBe false
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type correctly when it is a standard category', ->
      cat = new Label
      cat.name = 'inbox'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory()).toBe true
      expect(cat.isHiddenCategory()).toBe false
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type for `important` category when should not show important', ->
      cat = new Label
      cat.name = 'important'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory(false)).toBe false
      expect(cat.isHiddenCategory()).toBe true
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type correctly when it is a hidden category', ->
      cat = new Label
      cat.name = 'archive'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory()).toBe true
      expect(cat.isHiddenCategory()).toBe true
      expect(cat.isLockedCategory()).toBe false

    it 'assigns type correctly when it is a locked category', ->
      cat = new Label
      cat.name = 'sent'
      expect(cat.isUserCategory()).toBe false
      expect(cat.isStandardCategory()).toBe true
      expect(cat.isHiddenCategory()).toBe true
      expect(cat.isLockedCategory()).toBe true
