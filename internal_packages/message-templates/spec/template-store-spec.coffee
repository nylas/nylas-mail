{Message, Actions, DatabaseStore, DraftStore} = require 'nylas-exports'
TemplateStore = require '../lib/template-store'
fs = require 'fs-plus'
shell = require 'shell'

stubTemplatesDir = TemplateStore.templatesDirectory()

stubTemplateFiles = {
  'template1.html': '<p>bla1</p>',
  'template2.html': '<p>bla2</p>'
}

stubTemplates = [
  {id: 'template1.html', name: 'template1', path: "#{stubTemplatesDir}/template1.html"},
  {id: 'template2.html', name: 'template2', path: "#{stubTemplatesDir}/template2.html"},
]

describe "TemplateStore", ->
  beforeEach ->
    spyOn(fs, 'mkdir')
    spyOn(shell, 'showItemInFolder').andCallFake ->
    spyOn(fs, 'writeFile').andCallFake (path, contents, callback) ->
      callback(null)
    spyOn(fs, 'readFile').andCallFake (path, callback) ->
      filename = path.split('/').pop()
      callback(null, stubTemplateFiles[filename])

  it "should create the templates folder if it does not exist", ->
    spyOn(fs, 'exists').andCallFake (path, callback) -> callback(false)
    TemplateStore.init()
    expect(fs.mkdir).toHaveBeenCalled()

  it "should expose templates in the templates directory", ->
    spyOn(fs, 'exists').andCallFake (path, callback) -> callback(true)
    spyOn(fs, 'readdir').andCallFake (path, callback) -> callback(null, Object.keys(stubTemplateFiles))
    TemplateStore.init()
    expect(TemplateStore.items()).toEqual(stubTemplates)

  it "should watch the templates directory and reflect changes", ->
    watchCallback = null
    watchFired = false

    spyOn(fs, 'exists').andCallFake (path, callback) -> callback(true)
    spyOn(fs, 'watch').andCallFake (path, callback) -> watchCallback = callback
    spyOn(fs, 'readdir').andCallFake (path, callback) ->
      if watchFired
        callback(null, Object.keys(stubTemplateFiles))
      else
        callback(null, [])

    TemplateStore.init()
    expect(TemplateStore.items()).toEqual([])

    watchFired = true
    watchCallback()
    expect(TemplateStore.items()).toEqual(stubTemplates)

  describe "insertTemplateId", ->
    it "should insert the template with the given id into the draft with the given id", ->

      add = jasmine.createSpy('add')
      spyOn(DraftStore, 'sessionForLocalId').andCallFake ->
        Promise.resolve(changes: {add})

      runs ->
        TemplateStore._onInsertTemplateId
          templateId: 'template1.html',
          draftLocalId: 'localid-draft'
      waitsFor ->
        add.calls.length > 0
      runs ->
        expect(add).toHaveBeenCalledWith
          body: stubTemplateFiles['template1.html']

  describe "onCreateTemplate", ->
    beforeEach ->
      TemplateStore.init()
      spyOn(DraftStore, 'sessionForLocalId').andCallFake (draftLocalId) ->
        if draftLocalId is 'localid-nosubject'
          d = new Message(subject: '', body: '<p>Body</p>')
        else
          d = new Message(subject: 'Subject', body: '<p>Body</p>')
        session =
          draft: -> d
        Promise.resolve(session)

    it "should create a template with the given name and contents", ->
      TemplateStore._onCreateTemplate({name: '123', contents: 'bla'})
      item = TemplateStore.items()?[0]
      expect(item.id).toBe "123.html"
      expect(item.name).toBe "123"
      expect(item.path.split("/").pop()).toBe "123.html"

    it "should display an error if no name is provided", ->
      spyOn(TemplateStore, '_displayError')
      TemplateStore._onCreateTemplate({contents: 'bla'})
      expect(TemplateStore._displayError).toHaveBeenCalled()

    it "should display an error if no content is provided", ->
      spyOn(TemplateStore, '_displayError')
      TemplateStore._onCreateTemplate({name: 'bla'})
      expect(TemplateStore._displayError).toHaveBeenCalled()

    it "should save the template file to the templates folder", ->
      TemplateStore._onCreateTemplate({name: '123', contents: 'bla'})
      path = "#{stubTemplatesDir}/123.html"
      expect(fs.writeFile).toHaveBeenCalled()
      expect(fs.writeFile.mostRecentCall.args[0]).toEqual(path)
      expect(fs.writeFile.mostRecentCall.args[1]).toEqual('bla')

    it "should open the template so you can see it", ->
      TemplateStore._onCreateTemplate({name: '123', contents: 'bla'})
      path = "#{stubTemplatesDir}/123.html"
      expect(shell.showItemInFolder).toHaveBeenCalled()

    describe "when given a draft id", ->
      it "should create a template from the name and contents of the given draft", ->
        runs ->
          TemplateStore._onCreateTemplate({draftLocalId: 'localid-b'})
        waitsFor ->
          fs.writeFile.callCount > 0
        runs ->
          expect(TemplateStore.items().length).toEqual(1)

      it "should display an error if the draft has no subject", ->
        spyOn(TemplateStore, '_displayError')
        runs ->
          TemplateStore._onCreateTemplate({draftLocalId: 'localid-nosubject'})
        waitsFor ->
          TemplateStore._displayError.callCount > 0
        runs ->
          expect(TemplateStore._displayError).toHaveBeenCalled()

  describe "onShowTemplates", ->
    it "should open the templates folder in the Finder", ->
      TemplateStore._onShowTemplates()
      expect(shell.showItemInFolder).toHaveBeenCalled()
