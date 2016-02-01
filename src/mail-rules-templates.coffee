_ = require 'underscore'
NylasObservables = require 'nylas-observables'
{Template} = require './components/scenario-editor-models'

ConditionTemplates = [
  new Template('from', Template.Type.String, {
    name: 'From',
    valueForMessage: (message) ->
      _.pluck(message.from, 'email')
  })

  new Template('to', Template.Type.String, {
    name: 'To',
    valueForMessage: (message) ->
      _.pluck(message.to, 'email')
  })

  new Template('cc', Template.Type.String, {
    name: 'Cc',
    valueForMessage: (message) ->
      _.pluck(message.cc, 'email')
  })

  new Template('bcc', Template.Type.String, {
    name: 'Bcc',
    valueForMessage: (message) ->
      _.pluck(message.bcc, 'email')
  })

  new Template('anyRecipient', Template.Type.String, {
    name: 'Any Recipient',
    valueForMessage: (message) ->
      recipients = [].concat(message.to, message.cc, message.bcc, message.from)
      _.pluck(recipients, 'email')
  })

  new Template('anyAttachmentName', Template.Type.String, {
    name: 'Any attachment name',
    valueForMessage: (message) ->
      _.pluck(message.files, 'filename')
  })

  new Template('starred', Template.Type.Enum, {
    name: 'Starred',
    values: [{name: 'True', value: 'true'}, {name: 'False', value: 'false'}]
    valueLabel: 'is:'
    valueForMessage: (message) ->
      if message.starred then return 'true' else return 'false'
  })

  new Template('subject', Template.Type.String, {
    name: 'Subject',
    valueForMessage: (message) ->
      message.subject
  })

  new Template('body', Template.Type.String, {
    name: 'Body',
    valueForMessage: (message) ->
      message.body
  })
]

ActionTemplates = [
  new Template('markAsRead', Template.Type.None, {name: 'Mark as Read'})
  new Template('moveToTrash', Template.Type.None, {name: 'Move to Trash'})
  new Template('star', Template.Type.None, {name: 'Star'})
]


module.exports =
  ConditionMode:
    Any: 'any'
    All: 'all'

  ConditionTemplates: ConditionTemplates

  ConditionTemplatesForAccount: (account) ->
    return [] unless account
    return ConditionTemplates

  ActionTemplates: ActionTemplates

  ActionTemplatesForAccount: (account) ->
    return [] unless account

    templates = [].concat(ActionTemplates)

    CategoryNamesObservable = NylasObservables.Categories
      .forAccount(account)
      .sort()
      .map (cats) ->
        cats.map (cat) ->
          name: cat.displayName || cat.name
          value: cat.id

    if account.usesLabels()
      templates.unshift new Template('markAsImportant', Template.Type.None, {
        name: 'Mark as Important'
      })
      templates.unshift new Template('applyLabelArchive', Template.Type.None, {
        name: 'Archive'
      })
      templates.unshift new Template('applyLabel', Template.Type.Enum, {
        name: 'Apply Label'
        values: CategoryNamesObservable
      })

    else
      templates.push new Template('changeFolder', Template.Type.Enum, {
        name: 'Move Message'
        valueLabel: 'to folder:'
        values: CategoryNamesObservable
      })

    templates
