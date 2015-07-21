_ = require 'underscore'
moment = require 'moment'

File = require './file'
Label = require './label'
Folder = require './folder'
Model = require './model'
Contact = require './contact'
Attributes = require '../attributes'
NamespaceStore = require '../stores/namespace-store'

###
Public: The Message model represents a Message object served by the Nylas Platform API.
For more information about Messages on the Nylas Platform, read the
[Messages API Documentation](https://nylas.com/docs/api#messages)

Messages are a sub-object of threads. The content of a message is immutable (with the
exception being drafts). Nylas does not support operations such as move or delete on
individual messages; those operations should be performed on the message’s thread.
All messages are part of a thread, even if that thread has only one message.

## Attributes

`to`: {AttributeCollection} A collection of {Contact} objects

`cc`: {AttributeCollection} A collection of {Contact} objects

`bcc`: {AttributeCollection} A collection of {Contact} objects

`from`: {AttributeCollection} A collection of {Contact} objects.

`replyTo`: {AttributeCollection} A collection of {Contact} objects.

`date`: {AttributeDateTime} When the message was delivered. Queryable.

`subject`: {AttributeString} The subject of the thread. Queryable.

`snippet`: {AttributeString} A short, 140-character plain-text summary of the message body.

`unread`: {AttributeBoolean} True if the message is unread. Queryable.

`starred`: {AttributeBoolean} True if the message is starred. Queryable.

`draft`: {AttributeBoolean} True if the message is a draft. Queryable.

`version`: {AttributeNumber} The version number of the message. Message
   versions are used for drafts, and increment when attributes are changed.

`files`: {AttributeCollection} A set of {File} models representing
   the attachments on this thread.

`body`: {AttributeJoinedData} The HTML body of the message. You must specifically
 request this attribute when querying for a Message using the {{AttributeJoinedData::include}}
 method.

`pristine`: {AttributeBoolean} True if the message is a draft which has not been
 edited since it was created.

`threadId`: {AttributeString} The ID of the Message's parent {Thread}. Queryable.

`replyToMessageId`: {AttributeString} The ID of a {Message} that this message
 is in reply to.

This class also inherits attributes from {Model}

Section: Models
###
class Message extends Model

  @attributes: _.extend {}, Model.attributes,

    'to': Attributes.Collection
      modelKey: 'to'
      itemClass: Contact

    'cc': Attributes.Collection
      modelKey: 'cc'
      itemClass: Contact

    'bcc': Attributes.Collection
      modelKey: 'bcc'
      itemClass: Contact

    'from': Attributes.Collection
      modelKey: 'from'
      itemClass: Contact

    'replyTo': Attributes.Collection
      modelKey: 'replyTo'
      jsonKey: 'reply_to'
      itemClass: Contact

    'date': Attributes.DateTime
      queryable: true
      modelKey: 'date'

    'body': Attributes.JoinedData
      modelTable: 'MessageBody'
      modelKey: 'body'

    'files': Attributes.Collection
      modelKey: 'files'
      itemClass: File

    'unread': Attributes.Boolean
      queryable: true
      modelKey: 'unread'

    'starred': Attributes.Boolean
      queryable: true
      modelKey: 'starred'

    'snippet': Attributes.String
      modelKey: 'snippet'

    'threadId': Attributes.String
      queryable: true
      modelKey: 'threadId'
      jsonKey: 'thread_id'

    'subject': Attributes.String
      modelKey: 'subject'

    'draft': Attributes.Boolean
      modelKey: 'draft'
      jsonKey: 'draft'
      queryable: true

    'pristine': Attributes.Boolean
      modelKey: 'pristine'
      jsonKey: 'pristine'
      queryable: false

    'version': Attributes.Number
      modelKey: 'version'
      queryable: true

    'replyToMessageId': Attributes.String
      modelKey: 'replyToMessageId'
      jsonKey: 'reply_to_message_id'

    'folder': Attributes.Object
      modelKey: 'folder'
      itemClass: Folder

    'labels': Attributes.Collection
      queryable: true
      modelKey: 'labels'
      itemClass: Label


  @naturalSortOrder: ->
    Message.attributes.date.ascending()

  @additionalSQLiteConfig:
    setup: ->
      ['CREATE INDEX IF NOT EXISTS MessageListIndex ON Message(thread_id, date ASC)']

  constructor: ->
    super
    @subject ||= ""
    @to ||= []
    @cc ||= []
    @bcc ||= []
    @replyTo ||= []
    @files ||= []
    @

  toJSON: ->
    json = super
    json.file_ids = @fileIds()
    json.object = 'draft' if @draft
    json

  fromJSON: (json={}) ->
    super (json)

    # Only change the `draft` bit if the incoming json has an `object`
    # property. Because of `DraftChangeSet`, it's common for incoming json
    # to be an empty hash. In this case we want to leave the pre-existing
    # draft bit alone.
    if json.object?
      @draft = (json.object is 'draft')

    for file in (@files ? [])
      file.namespaceId = @namespaceId
    return @

  # We calculate the list of participants instead of grabbing it from
  # a parent because it is a better source of ground truth, and saves us
  # from more dependencies.
  participants: ->
    participants = {}
    contacts = _.union((@to ? []), (@cc ? []), (@from ? []))
    for contact in contacts
      if contact? and contact.email?.length > 0
        participants["#{(contact?.email ? "").toLowerCase().trim()} #{(contact?.name ? "").toLowerCase().trim()}"] = contact if contact?
    return _.values(participants)

  # Returns a hash with `to` and `cc` keys for authoring a new draft in response
  # to this message. Takes `replyTo` and other important state into account.
  participantsForReplyAll: ->
    to = []
    cc = []

    if @from[0].email is NamespaceStore.current().emailAddress
      to = @to
      cc = @cc
    else
      excluded = @from.map (c) -> c.email
      excluded.push(NamespaceStore.current().emailAddress)
      if @replyTo.length
        to = @replyTo
      else
        to = @from
      cc = [].concat(@cc, @to).filter (p) ->
        !_.contains(excluded, p.email)

    {to, cc}

  participantsForReply: ->
    to = []
    cc = []

    if @from[0].email is NamespaceStore.current().emailAddress
      to = @to
    else if @replyTo.length
      to = @replyTo
    else
      to = @from

    {to, cc}

  # Public: Returns an {Array} of {File} IDs
  fileIds: ->
    _.map @files, (file) -> file.id

  plainTextBody: ->
    if (@body ? "").trim().length is 0 then return ""
    (new DOMParser()).parseFromString(@body, "text/html").body.innerText

  fromContact: ->
    @from?[0] ? new Contact(name: 'Unknown', email: 'Unknown')

  replyAttributionLine: ->
    "On #{@formattedDate()}, #{@fromContact().messageName()} wrote:"

  formattedDate: -> moment(@date).format("MMM D YYYY, [at] h:mm a")

module.exports = Message
