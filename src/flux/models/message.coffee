_ = require 'underscore'
moment = require 'moment'

File = require './file'
Label = require './label'
Folder = require './folder'
Model = require './model'
Event = require './event'
Contact = require './contact'
Attributes = require '../attributes'
AccountStore = require '../stores/account-store'

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

    'events': Attributes.Collection
      modelKey: 'events'
      itemClass: Event

    'starred': Attributes.Boolean
      queryable: true
      modelKey: 'starred'

    'snippet': Attributes.String
      modelKey: 'snippet'

    'threadId': Attributes.ServerId
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

    'replyToMessageId': Attributes.ServerId
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
      ['CREATE INDEX IF NOT EXISTS MessageListIndex ON Message(account_id, thread_id, date ASC)',
       'CREATE UNIQUE INDEX IF NOT EXISTS MessageDraftIndex ON Message(client_id)',
       'CREATE UNIQUE INDEX IF NOT EXISTS MessageBodyIndex ON MessageBody(id)']

  constructor: ->
    super
    @subject ||= ""
    @to ||= []
    @cc ||= []
    @bcc ||= []
    @replyTo ||= []
    @files ||= []
    @events ||= []
    @

  toJSON: (options) ->
    json = super(options)
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
      file.accountId = @accountId
    return @

  canReplyAll: ->
    @cc.length > 0 or @to.length > 1

  # Public: Returns a set of uniqued message participants by combining the
  # `to`, `cc`, and `from` fields.
  participants: ->
    participants = {}
    contacts = _.union((@to ? []), (@cc ? []), (@from ? []))
    for contact in contacts
      if contact? and contact.email?.length > 0
        participants["#{(contact?.email ? "").toLowerCase().trim()} #{(contact?.name ? "").toLowerCase().trim()}"] = contact if contact?
    return _.values(participants)

  # Public: Returns a hash with `to` and `cc` keys for authoring a new draft in
  # "reply all" to this message. This method takes into account whether the
  # message is from the current user, and also looks at the replyTo field.
  participantsForReplyAll: ->
    to = []
    cc = []

    if @isFromMe()
      to = @to
      cc = @cc
    else
      excluded = @from.map (c) -> c.email
      excluded.push(AccountStore.current().emailAddress)
      if @replyTo.length
        to = @replyTo
      else
        to = @from

      cc = [].concat(@cc, @to)
      cc = _.filter cc, (p) -> !_.contains(excluded, p.email)

    to = _.uniq to, (p) -> p.email.toLowerCase().trim()
    cc = _.uniq cc, (p) -> p.email.toLowerCase().trim()
    {to, cc}

  # Public: Returns a hash with `to` and `cc` keys for authoring a new draft in
  # "reply" to this message. This method takes into account whether the
  # message is from the current user, and also looks at the replyTo field.
  participantsForReply: ->
    to = []
    cc = []

    if @isFromMe()
      to = @to
    else if @replyTo.length
      to = @replyTo
    else
      to = @from

    to = _.uniq to, (p) -> p.email.toLowerCase().trim()
    {to, cc}

  # Public: Returns an {Array} of {File} IDs
  fileIds: ->
    _.map @files, (file) -> file.id

  # Public: Returns true if this message is from the current user's email
  # address. In the future, this method will take into account all of the
  # user's email addresses and accounts.
  isFromMe: ->
    @from[0]?.isMe()

  # Public: Returns a plaintext version of the message body using Chromium's
  # DOMParser. Use with care.
  plainTextBody: ->
    if (@body ? "").trim().length is 0 then return ""
    (new DOMParser()).parseFromString(@body, "text/html").body.innerText

  fromContact: ->
    @from?[0] ? new Contact(name: 'Unknown', email: 'Unknown')

  # Public: Returns the standard attribution line for this message,
  # localized for the current user.
  # ie "On Dec. 12th, 2015 at 4:00PM, Ben Gotow wrote:"
  replyAttributionLine: ->
    "On #{@formattedDate()}, #{@fromContact().toString()} wrote:"

  formattedDate: -> moment(@date).format("MMM D YYYY, [at] h:mm a")

module.exports = Message
