
utils =
  modelClassMap: ->
    Thread = require './thread'
    Message = require './message'
    Namespace = require './namespace'
    Tag = require './tag'
    File = require './file'
    Contact = require './contact'
    LocalLink = require './local-link'
    Event = require './event'
    Calendar = require './calendar'

    ## TODO move to inside of individual Salesforce package. See https://trello.com/c/tLAGLyeb/246-move-salesforce-models-into-individual-package-db-models-for-packages-various-refactors
    SalesforceAssociation = require './salesforce-association'
    SalesforceContact = require './salesforce-contact'
    SalesforceTask = require './salesforce-task'

    SaveDraftTask = require '../tasks/save-draft'
    SendDraftTask = require '../tasks/send-draft'
    DestroyDraftTask = require '../tasks/destroy-draft'
    AddRemoveTagsTask = require '../tasks/add-remove-tags'
    MarkThreadReadTask = require '../tasks/mark-thread-read'
    MarkMessageReadTask = require '../tasks/mark-message-read'
    FileUploadTask = require '../tasks/file-upload-task'

    return {
      'thread': Thread
      'message': Message
      'draft': Message
      'contact': Contact
      'namespace': Namespace
      'file': File
      'tag': Tag
      'locallink': LocalLink
      'calendar': Calendar
      'event': Event
      'salesforceassociation': SalesforceAssociation
      'salesforcecontact': SalesforceContact
      'SalesforceTask': SalesforceTask

      'MarkThreadReadTask': MarkThreadReadTask
      'MarkMessageReadTask': MarkMessageReadTask
      'AddRemoveTagsTask': AddRemoveTagsTask
      'SendDraftTask': SendDraftTask
      'SaveDraftTask': SaveDraftTask
      'DestroyDraftTask': DestroyDraftTask
      'FileUploadTask': FileUploadTask
    }

  modelFromJSON: (json) ->
    # These imports can't go at the top of the file
    # because they cause circular requires
    klass = utils.modelClassMap()[json.object]
    throw (new Error "Unsure of how to inflate #{JSON.stringify(json)}") unless klass
    throw (new Error "Cannot inflate #{json.object}, require did not return constructor") unless klass instanceof Function
    object = new klass()
    object.fromJSON(json)
    object

  modelReviver: (k, v) ->
    return v if k == ""
    v = utils.modelFromJSON(v) if (v instanceof Object && v['object'])
    v

  generateTempId: ->
    s4 = ->
      Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
    'local-' + s4() + s4() + '-' + s4()

  isTempId: (id) ->
    return false unless id
    id[0..5] == 'local-'

  tableNameForJoin: (primaryKlass, secondaryKlass) ->
    "#{primaryKlass.name}-#{secondaryKlass.name}"

module.exports = utils
