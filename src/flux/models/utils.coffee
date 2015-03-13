_ = require 'underscore-plus'
fs = require('fs-plus')
path = require('path')

Utils =
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

    SyncbackDraftTask = require '../tasks/syncback-draft'
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
      'SyncbackDraftTask': SyncbackDraftTask
      'DestroyDraftTask': DestroyDraftTask
      'FileUploadTask': FileUploadTask
    }

  modelFromJSON: (json) ->
    # These imports can't go at the top of the file
    # because they cause circular requires
    klass = Utils.modelClassMap()[json.object]
    throw (new Error "Unsure of how to inflate #{JSON.stringify(json)}") unless klass
    throw (new Error "Cannot inflate #{json.object}, require did not return constructor") unless klass instanceof Function
    object = new klass()
    object.fromJSON(json)
    object

  modelReviver: (k, v) ->
    return v if k == ""
    v = Utils.modelFromJSON(v) if (v instanceof Object && v['object'])
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
  
  imageNamed: (fullname) ->
    [name, ext] = fullname.split('.')

    if Utils.images is undefined
      start = Date.now()
      {resourcePath} = atom.getLoadSettings()
      imagesPath = path.join(resourcePath, 'static', 'images')
      files = fs.listTreeSync(imagesPath)

      Utils.images = {}
      Utils.images[path.basename(file)] = file for file in files

    if window.devicePixelRatio > 1
      return Utils.images["#{name}@2x.#{ext}"] ? Utils.images[fullname] ? Utils.images["#{name}@1x.#{ext}"]
    else
      return Utils.images["#{name}@1x.#{ext}"] ? Utils.images[fullname] ? Utils.images["#{name}@2x.#{ext}"]

  subjectWithPrefix: (subject, prefix) ->
    if subject.search(/fwd:/i) is 0
      return subject.replace(/fwd:/i, prefix)
    else if subject.search(/re:/i) is 0
      return subject.replace(/re:/i, prefix)
    else
      return "#{prefix} #{subject}"

  # A wrapper around String#search(). Returns the index of the first match
  # or returns -1 if there are no matches
  quotedTextIndex: (html) ->
    # I know this is gross - one day we'll replace it with a nice system.
    return false unless html

    regexs = [
      /<blockquote/i, # blockquote element
      /\n[ ]*(>|&gt;)/, # Plaintext lines beginning with >
      /<[br|p][ ]*>[\n]?[ ]*&gt;/i, # HTML lines beginning with >
      /[\n|>]On .* wrote:[\n|<]/, #On ... wrote: on it's own line
      /.gmail_quote/ # gmail quote class class
    ]

    for regex in regexs
      foundIndex = html.search(regex)
      if foundIndex >= 0 then return foundIndex

    return -1

  stripQuotedText: (html) ->
    return html if Utils.quotedTextIndex(html) is -1

    # Split the email into lines and remove lines that begin with > or &gt;
    lines = html.split(/(\n|<br[^>]*>)/)

    # Remove lines that are newlines - we'll add them back in when we join.
    # We had to break them out because we want to preserve <br> elements.
    lines = _.reject lines, (line) -> line == '\n'

    regexs = [
      /\n[ ]*(>|&gt;)/, # Plaintext lines beginning with >
      /<[br|p][ ]*>[\n]?[ ]*[>|&gt;]/i, # HTML lines beginning with >
      /[\n|>]On .* wrote:[\n|<]/, #On ... wrote: on it's own line
    ]
    for ii in [lines.length-1..0] by -1
      continue if not lines[ii]?
      for regex in regexs
        # Never remove a line with a blockquote start tag, because it
        # quotes multiple lines, not just the current line!
        if lines[ii].match("<blockquote")
          break
        if lines[ii].match(regex)
          lines.splice(ii,1)
          # Remove following line if its just a spacer-style element
          lines.splice(ii,1) if lines[ii]?.match('<br[^>]*>')?[0] is lines[ii]
          break

    # Return remaining compacted email body
    lines.join('\n')

  # Checks to see if a particular node is visible and any of its parents
  # are visible.
  #
  # WARNING. This is a fairly expensive operation and should be used
  # sparingly.
  nodeIsVisible: (node) ->
    while node
      style = window.getComputedStyle(node)
      node = node.parentNode
      continue unless style?
      # NOTE: opacity must be soft ==
      if style.opacity is 0 or style.opacity is "0" or style.visibility is "hidden" or style.display is "none"
        return false
    return true

module.exports = Utils
