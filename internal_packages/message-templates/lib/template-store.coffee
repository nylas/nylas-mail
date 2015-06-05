Reflux = require 'reflux'
_ = require 'underscore'
{DatabaseStore, DraftStore, Actions, Message} = require 'nylas-exports'
shell = require 'shell'
path = require 'path'
fs = require 'fs-plus'

TemplateStore = Reflux.createStore
  init: ->
    @_setStoreDefaults()
    @_registerListeners()

    @_templatesDir = path.join(atom.getConfigDirPath(), 'templates')

    # I know this is a bit of pain but don't do anything that
    # could possibly slow down app launch
    fs.exists @_templatesDir, (exists) =>
      if exists
        @_populate()
        fs.watch @_templatesDir, => @_populate()
      else
        fs.mkdir @_templatesDir, =>
          fs.watch @_templatesDir, => @_populate()


  ########### PUBLIC #####################################################

  items: ->
    @_items

  templatesDirectory: ->
    @_templatesDir


  ########### PRIVATE ####################################################

  _setStoreDefaults: ->
    @_items = []

  _registerListeners: ->
    @listenTo Actions.insertTemplateId, @_onInsertTemplateId
    @listenTo Actions.createTemplate, @_onCreateTemplate
    @listenTo Actions.showTemplates, @_onShowTemplates

  _populate: ->
    fs.readdir @_templatesDir, (err, filenames) =>
      @_items = []
      for filename in filenames
        continue if filename[0] is '.'
        displayname = path.basename(filename, path.extname(filename))
        @_items.push
          id: filename,
          name: displayname,
          path: path.join(@_templatesDir, filename)
      @trigger(@)

  _onCreateTemplate: ({draftLocalId, name, contents} = {}) ->
    if draftLocalId
      DraftStore.sessionForLocalId(draftLocalId).then (session) =>
        draft = session.draft()
        name ?= draft.subject
        contents ?= draft.body
        if not name or name.length is 0
          return @_displayError("Give your draft a subject to name your template.")
        if not contents or contents.length is 0
          return @_displayError("To create a template you need to fill the body of the current draft.")
        @_writeTemplate(name, contents)

    else
      if not name or name.length is 0
        return @_displayError("You must provide a name for your template.")
      if not contents or contents.length is 0
        return @_displayError("You must provide contents for your template.")
      @_writeTemplate(name, contents)

  _onShowTemplates: ->
    shell.showItemInFolder(@_items[0]?.path || @_templatesDir)

  _displayError: (message) ->
    dialog = require('remote').require('dialog')
    dialog.showErrorBox('Template Creation Error', message)

  _writeTemplate: (name, contents) ->
    filename = "#{name}.html"
    templatePath = path.join(@_templatesDir, filename)
    fs.writeFile templatePath, contents, (err) =>
      @_displayError(err) if err
      shell.showItemInFolder(templatePath)
      @_items.push
        id: filename,
        name: name,
        path: templatePath
      @trigger(@)

  _onInsertTemplateId: ({templateId, draftLocalId} = {}) ->
    template = _.find @_items, (item) -> item.id is templateId
    return unless template

    fs.readFile template.path, (err, data) ->
      body = data.toString()
      DraftStore.sessionForLocalId(draftLocalId).then (session) ->
        session.changes.add(body: body)

module.exports = TemplateStore
