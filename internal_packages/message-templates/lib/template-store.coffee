Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore, DraftStore, Actions, Message} = require 'inbox-exports'
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
      DatabaseStore.findByLocalId(Message, draftLocalId).then (draft) =>
        if draft
          name ?= draft.subject
          contents ?= draft.body
        @_writeTemplate(name, contents)
    else
      @_writeTemplate(name, contents)

  _onShowTemplates: ->
    # show in finder how?
    shell = require 'shell'
    shell.showItemInFolder(@_items[0]?.path || @_templatesDir)

  _writeTemplate: (name, contents) ->
    throw new Error("You must provide a template name") unless name
    throw new Error("You must provide template contents") unless contents
    filename = "#{name}.html"
    templatePath = path.join(@_templatesDir, filename)
    fs.writeFile templatePath, contents, (err) =>
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
      session = DraftStore.sessionForLocalId(draftLocalId)
      session.changes.add(body: body)

module.exports = TemplateStore
